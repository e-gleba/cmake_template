#include "main.hpp"

#include <array>
#include <cstddef>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>

#include <android/log.h>
#include <jni.h>

#include <doctest/doctest.h>

namespace {

// ── Android logcat streambuf ─────────────────────────────────────────────
    class android_log_buf final : public std::streambuf {
        static constexpr auto tag = "native_tests";
        std::array<char, 512> buf_{};

    public:
        android_log_buf() { reset(); }

        ~android_log_buf() override { flush(); }

    protected:
        int_type overflow(int_type c) override {
            flush();
            if (c == traits_type::eof()) return traits_type::not_eof(c);
            *pptr() = static_cast<char>(c);
            pbump(1);
            if (c == '\n') flush();
            return c;
        }

        int sync() override {
            flush();
            return 0;
        }

    private:
        void reset() { setp(buf_.data(), buf_.data() + buf_.size() - 1); }

        void flush() {
            auto n = static_cast<std::size_t>(pptr() - pbase());
            if (!n) return;
            if (buf_[n - 1] == '\n') --n;
            buf_[n] = '\0';
            if (n) __android_log_write(ANDROID_LOG_INFO, tag, buf_.data());
            reset();
        }
    };

    struct log_init {
        android_log_buf buf;

        log_init() noexcept {
            std::cout.rdbuf(&buf);
            std::cerr.rdbuf(&buf);
        }
    } _log_init{};

// ── JNI helpers ──────────────────────────────────────────────────────────
    struct jni_string final {
        JNIEnv *env;
        jstring ref;
        const char *data;

        jni_string(JNIEnv *e, jstring s)
                : env(e), ref(s), data(e->GetStringUTFChars(s, nullptr)) {
            if (!data) throw std::runtime_error("GetStringUTFChars failed");
        }

        ~jni_string() { env->ReleaseStringUTFChars(ref, data); }

        jni_string(const jni_string &) = delete;

        jni_string &operator=(const jni_string &) = delete;

        [[nodiscard]] std::string_view view() const noexcept { return data; }

        [[nodiscard]] const char *c_str() const noexcept { return data; }
    };

    inline void throw_java(JNIEnv *env, std::string_view msg) {
        if (jclass ex = env->FindClass("java/lang/RuntimeException")) {
            env->ThrowNew(ex, msg.data());
            env->DeleteLocalRef(ex);
        }
    }

} // namespace

// ── JNI entry points ─────────────────────────────────────────────────────
extern "C" {

JNIEXPORT jobjectArray JNICALL
Java_com_egleba_app_NativeDoctestTests_getTestNames(JNIEnv *env,
                                                    jclass) {
    try {
        auto sc = env->FindClass("java/lang/String");
        auto tests = egleba::doctest::get_all_tests();
        auto out = env->NewObjectArray(static_cast<jsize>(tests.size()), sc,
                                       nullptr);

        jsize i = 0;
        for (const auto &name: tests) {
            auto js = env->NewStringUTF(name.c_str());
            env->SetObjectArrayElement(out, i++, js);
            env->DeleteLocalRef(js);
        }
        env->DeleteLocalRef(sc);
        return out;
    } catch (const std::exception &e) {
        throw_java(env, e.what());
    } catch (...) {
        throw_java(env, "C++ exception in getTestNames");
    }
    return nullptr;
}

JNIEXPORT jboolean JNICALL
Java_com_egleba_app_NativeDoctestTests_runTest(JNIEnv *env,
                                               jclass,
                                               jstring jname) {
    try {
        jni_string name(env, jname);

        doctest::Context ctx{};
        ctx.setOption("test-case", name.c_str());
        ctx.setOption("duration", true);
        ctx.setOption("no-exitcode", true);

        return ctx.run() == 0 ? JNI_TRUE : JNI_FALSE;
    } catch (const std::exception &e) {
        throw_java(env, e.what());
    } catch (...) {
        throw_java(env, "C++ exception in runTest");
    }
    return JNI_FALSE;
}

} // extern "C"
