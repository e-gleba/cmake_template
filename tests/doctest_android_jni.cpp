#include "main.hpp"

#include <array>
#include <concepts>
#include <cstddef>
#include <exception>
#include <iostream>
#include <optional>
#include <ranges>
#include <span>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>

#include <android/log.h>
#include <jni.h>

#include <doctest/doctest.h>

namespace {

// ─── Android logcat stream buffer ─────────────────────────────────────────────

    class android_log_streambuf final : public std::streambuf {
    public:
        explicit android_log_streambuf(const char *tag) noexcept: tag_{tag} {
            reset_put_area();
        }

        ~android_log_streambuf() override { flush_buffer(); }

        android_log_streambuf(const android_log_streambuf &) = delete;

        android_log_streambuf &
        operator=(const android_log_streambuf &) = delete;

        android_log_streambuf(android_log_streambuf &&) = delete;

        android_log_streambuf &operator=(android_log_streambuf &&) = delete;

    protected:
        int_type overflow(int_type ch) override {
            flush_buffer();
            if (traits_type::eq_int_type(ch, traits_type::eof())) {
                return traits_type::not_eof(ch);
            }
            *pptr() = traits_type::to_char_type(ch);
            pbump(1);
            if (ch == '\n') {
                flush_buffer();
            }
            return ch;
        }

        int sync() override {
            flush_buffer();
            return 0;
        }

    private:
        static constexpr std::size_t buffer_capacity = 512;

        [[nodiscard]] std::span<char> usable_area() noexcept {
            // last byte reserved for null terminator inserted on flush
            return std::span{buffer_}.first(buffer_.size() - 1);
        }

        void reset_put_area() noexcept {
            const auto area = usable_area();
            setp(area.data(), area.data() + area.size());
        }

        // NOLINTNEXTLINE(bugprone-exception-escape) - at() cannot throw: indices are provably in range
        void flush_buffer() noexcept {
            const auto raw_length = static_cast<std::size_t>(pptr() - pbase());
            const auto length = (raw_length > 0 &&
                                 buffer_.at(raw_length - 1) == '\n')
                                ? raw_length - 1
                                : raw_length;
            if (length > 0) {
                buffer_.at(length) = '\0';
                __android_log_write(ANDROID_LOG_INFO, tag_, buffer_.data());
            }
            reset_put_area();
        }

        const char *tag_;
        std::array<char, buffer_capacity> buffer_{};
    };

// ─── Process-wide stdout/stderr → logcat redirection ──────────────────────────

    class log_redirector final {
    public:
        log_redirector() noexcept
                : saved_cout_{std::cout.rdbuf(&buffer_)},
                  saved_cerr_{std::cerr.rdbuf(&buffer_)} {}

        ~log_redirector() {
            std::cout.rdbuf(saved_cout_);
            std::cerr.rdbuf(saved_cerr_);
        }

        log_redirector(const log_redirector &) = delete;

        log_redirector &operator=(const log_redirector &) = delete;

        log_redirector(log_redirector &&) = delete;

        log_redirector &operator=(log_redirector &&) = delete;

    private:
        android_log_streambuf buffer_{"native_tests"};
        std::streambuf *saved_cout_;
        std::streambuf *saved_cerr_;
    };

    const log_redirector g_log_redirector{};

// ─── JNI RAII helpers ─────────────────────────────────────────────────────────

    class jni_utf_string final {
    public:
        jni_utf_string(JNIEnv *env, jstring source)
                : env_{env},
                  source_{source},
                  data_{env->GetStringUTFChars(source, nullptr)} {
            if (data_ == nullptr) {
                throw std::runtime_error{"JNI GetStringUTFChars returned null"};
            }
        }

        ~jni_utf_string() { env_->ReleaseStringUTFChars(source_, data_); }

        jni_utf_string(const jni_utf_string &) = delete;

        jni_utf_string &operator=(const jni_utf_string &) = delete;

        jni_utf_string(jni_utf_string &&) = delete;

        jni_utf_string &operator=(jni_utf_string &&) = delete;

        [[nodiscard]] std::string_view view() const noexcept { return data_; }

        [[nodiscard]] const char *c_str() const noexcept { return data_; }

    private:
        JNIEnv *env_;
        jstring source_;
        const char *data_;
    };

    template<typename T>
    concept jni_reference = std::is_pointer_v<T> &&
                            std::convertible_to<T, jobject>;

    template<jni_reference T>
    class jni_local_ref final {
    public:
        jni_local_ref(JNIEnv *env, T ref) noexcept: env_{env}, ref_{ref} {}

        ~jni_local_ref() {
            if (ref_ != nullptr) {
                env_->DeleteLocalRef(ref_);
            }
        }

        jni_local_ref(const jni_local_ref &) = delete;

        jni_local_ref &operator=(const jni_local_ref &) = delete;

        jni_local_ref(jni_local_ref &&other) noexcept
                : env_{other.env_}, ref_{std::exchange(other.ref_, nullptr)} {}

        jni_local_ref &operator=(jni_local_ref &&other) noexcept {
            if (this != &other) {
                if (ref_ != nullptr) {
                    env_->DeleteLocalRef(ref_);
                }
                env_ = other.env_;
                ref_ = std::exchange(other.ref_, nullptr);
            }
            return *this;
        }

        [[nodiscard]] T get() const noexcept { return ref_; }

        [[nodiscard]] T release() noexcept {
            return std::exchange(ref_, nullptr);
        }

        [[nodiscard]] explicit operator bool() const noexcept {
            return ref_ != nullptr;
        }

    private:
        JNIEnv *env_;
        T ref_;
    };

// ─── Java exception bridging ──────────────────────────────────────────────────

    void throw_java_runtime_exception(JNIEnv *env,
                                      std::string_view message) noexcept {
        if (env->ExceptionCheck() == JNI_TRUE) {
            return; // never clobber pending exception
        }

        if (jni_local_ref<jclass> cls{env, env->FindClass(
                "java/lang/RuntimeException")}) {
            env->ThrowNew(cls.get(), std::string{message}.c_str());
        }
    }

    template<std::invocable Fn>
    auto guard_jni(JNIEnv *env, std::string_view context, Fn &&fn) noexcept
    -> std::invoke_result_t<Fn> {
        using result_t = std::invoke_result_t<Fn>;
        try {
            return std::forward<Fn>(fn)();
        } catch (const std::exception &ex) {
            throw_java_runtime_exception(env, ex.what());
        } catch (...) {
            throw_java_runtime_exception(
                    env, std::string{"unknown C++ exception in "} += context);
        }
        if constexpr (!std::is_void_v<result_t>) {
            return result_t{};
        }
    }

// ─── Test runner ──────────────────────────────────────────────────────────────

    // Runs a single doctest case with its console report captured.
    //
    // no-exitcode must stay OFF: with it, Context::run() returns 0 even when
    // cases fail (doctest context.cpp: `if (p->numTestCasesFailed &&
    // !p->no_exitcode) return EXIT_FAILURE;`), so every JNI call would report
    // success and failing cases would never reach the JUnit results.
    //
    // Returns the captured report on failure, nullopt on pass. The report is
    // also mirrored to logcat through the process-wide redirect, so device
    // logs keep the full output either way.
    [[nodiscard]] std::optional<std::string>
    run_single_doctest(const char *test_case_name) {
        std::ostringstream report;

        doctest::Context context {};
        context.setOption("test-case", test_case_name);
        context.setOption("duration", true);
        context.setCout(&report);

        const int exit_code = context.run();

        const std::string output = report.str();
        if (!output.empty()) {
            std::cout << output;
        }

        if (exit_code == 0) {
            return std::nullopt;
        }
        return output;
    }

    template<std::ranges::sized_range Range>
    requires requires(std::ranges::range_reference_t<Range> item) {
        { item.c_str() } -> std::convertible_to<const char *>;
    }
    [[nodiscard]] jobjectArray
    to_java_string_array(JNIEnv *env, const Range &items) {
        jni_local_ref<jclass> string_class{env,
                                           env->FindClass("java/lang/String")};
        if (!string_class) {
            throw std::runtime_error{"failed to resolve java/lang/String"};
        }

        jni_local_ref<jobjectArray> array{
                env,
                env->NewObjectArray(
                        static_cast<jsize>(std::ranges::size(items)),
                        string_class.get(),
                        nullptr)};
        if (!array) {
            throw std::runtime_error{"NewObjectArray returned null"};
        }

        jsize index = 0;
        for (const auto &item: items) {
            jni_local_ref<jstring> element{env,
                                           env->NewStringUTF(item.c_str())};
            if (!element) {
                throw std::runtime_error{"NewStringUTF returned null"};
            }
            env->SetObjectArrayElement(array.get(), index++, element.get());
        }
        return array.release();
    }

} // namespace

// ─── JNI entry points ─────────────────────────────────────────────────────────

extern "C" {

// NOLINTBEGIN(readability-identifier-naming) - JNI export names are fixed by the Java native declarations
JNIEXPORT jobjectArray JNICALL
Java_com_egleba_app_NativeDoctestTests_getTestNames(JNIEnv *env,
                                                    jclass /*unused*/) {
    return guard_jni(env, "getTestNames", [env] {
        return to_java_string_array(env, egleba::doctest::get_all_tests());
    });
}

// Returns null when the case passes, or the captured doctest report when it
// fails — the Java runner turns a non-null report into an AssertionError, so
// the native assertion details land in the JUnit failure message and XML.
JNIEXPORT jstring JNICALL
Java_com_egleba_app_NativeDoctestTests_runTest(JNIEnv *env, jclass /*unused*/,
                                               jstring jname) {
    return guard_jni(env, "runTest", [env, jname]() -> jstring {
        const jni_utf_string test_name{env, jname};
        const std::optional<std::string> failure =
                run_single_doctest(test_name.c_str());
        if (!failure.has_value()) {
            return nullptr;
        }
        return env->NewStringUTF(failure->c_str());
    });
}
// NOLINTEND(readability-identifier-naming)

} // extern "C"
