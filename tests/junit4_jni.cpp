#include <algorithm>
#include <array>
#include <cstddef>
#include <format>
#include <iostream>
#include <iterator>
#include <ranges>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

#include <android/log.h>
#include <jni.h>

#include <doctest/doctest.h>

#include <main.hpp> // get_all_tests() -> std::set<std::string>

namespace {
// -------------------------------------------------------------------------
// Android logcat streambuf — zero-copy, line-buffered
// -------------------------------------------------------------------------
class android_log_buf final : public std::streambuf
{
    static constexpr char tag[] = "native_tests";
    std::array<char, 512> buffer_{};

public:
    android_log_buf()
    {
        auto s = std::span(buffer_);
        setp(s.data(), s.data() + s.size() - 1);
    }

    ~android_log_buf() override { flush(); }

protected:
    int_type overflow(int_type ch) override
    {
        if (ch == traits_type::eof() || pptr() == epptr())
            flush();

        if (ch == traits_type::eof())
            return traits_type::not_eof(ch);

        *pptr() = static_cast<char>(ch);
        pbump(1);

        if (ch == '\n')
            flush();

        return ch;
    }

    int sync() override
    {
        flush();
        return 0;
    }

private:
    void flush()
    {
        auto len = static_cast<std::size_t>(pptr() - pbase());
        if (len == 0)
            return;

        if (buffer_[len - 1] == '\n')
            buffer_[--len] = '\0';
        else
            buffer_[len] = '\0';

        if (len > 0)
            __android_log_write(ANDROID_LOG_INFO, tag, buffer_.data());

        auto s = std::span(buffer_);
        setp(s.data(), s.data() + s.size() - 1);
    }
};

struct log_redirector final
{
    android_log_buf buf;
    log_redirector()
    {
        std::cout.rdbuf(&buf);
        std::cerr.rdbuf(&buf);
    }
} log_redirect;

// -------------------------------------------------------------------------
// JNI RAII helpers
// -------------------------------------------------------------------------
struct jni_utf_chars final
{
    JNIEnv*     env;
    jstring     ref;
    const char* data;

    jni_utf_chars(JNIEnv* e, jstring s)
        : env(e)
        , ref(s)
        , data(env->GetStringUTFChars(s, nullptr))
    {
        if (!data)
            throw std::runtime_error("GetStringUTFChars failed");
    }

    ~jni_utf_chars()
    {
        if (data)
            env->ReleaseStringUTFChars(ref, data);
    }

    [[nodiscard]] std::string_view view() const { return data; }
    [[nodiscard]] const char*      c_str() const { return data; }

    jni_utf_chars(const jni_utf_chars&)            = delete;
    jni_utf_chars& operator=(const jni_utf_chars&) = delete;
};

inline void throw_java_exception(JNIEnv* env, const char* msg)
{
    if (const jclass ex = env->FindClass("java/lang/RuntimeException")) {
        env->ThrowNew(ex, msg);
        env->DeleteLocalRef(ex);
    }
}
} // namespace

// =============================================================================
// JNI entry points — every path catches C++ exceptions before returning to JVM
// =============================================================================
extern "C" {

JNIEXPORT jobjectArray JNICALL
Java_com_egleba_app_AppActivityTest_getTestNames(JNIEnv* env, jclass)
{
    try {
        constexpr std::string_view string_class = "java/lang/String";
        jclass                     sc = env->FindClass(string_class.data());
        if (!sc) {
            env->ExceptionClear();
            throw std::runtime_error(
                std::format("FindClass failed for {}", string_class));
        }

        const std::set<std::string>   tests = get_all_tests();
        jobjectArray out =
            env->NewObjectArray(static_cast<jsize>(tests.size()), sc, nullptr);
        env->DeleteLocalRef(sc);

        if (!out) {
            throw std::runtime_error(
                std::format("NewObjectArray failed (size={})", tests.size()));
        }

        for (jsize i = 0; const auto& name : tests) {
            jstring js = env->NewStringUTF(name.c_str());
            if (!js) {
                throw std::runtime_error(
                    std::format("NewStringUTF failed for '{}'", name));
            }

            env->SetObjectArrayElement(out, i++, js);
            env->DeleteLocalRef(js);

            if (env->ExceptionCheck()) {
                env->ExceptionClear();
                throw std::runtime_error(std::format(
                    "SetObjectArrayElement failed at index {}", i - 1));
            }
        }

        return out;
    } catch (const std::exception& e) {
        throw_java_exception(env, e.what());
        return nullptr;
    } catch (...) {
        throw_java_exception(env, "Unknown C++ exception in getTestNames");
        return nullptr;
    }
}

JNIEXPORT jboolean JNICALL
Java_com_egleba_app_AppActivityTest_runTest(JNIEnv* env, jclass, jstring jname)
{
    try {
        const jni_utf_chars name(env, jname);

        doctest::Context ctx {};
        ctx.setOption("test-case", name.c_str());
        ctx.setOption("duration", true);
        ctx.setOption("no-exitcode", true);

        return ctx.run() == 0 ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception& e) {
        throw_java_exception(env, e.what());
        return JNI_FALSE;
    } catch (...) {
        throw_java_exception(env, "Unknown C++ exception in runTest");
        return JNI_FALSE;
    }
}

} // extern "C"
