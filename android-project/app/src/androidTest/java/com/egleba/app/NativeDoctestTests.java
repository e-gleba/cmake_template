package com.egleba.app;

import android.os.Build;
import static org.junit.Assume.assumeTrue;

import org.junit.runner.RunWith;

/// On-device native test runner for Android instrumentation tests.
///
/// Bridges the doctest cases compiled into libtests.so into Android's JUnit
/// instrumentation pipeline: [DoctestRunner] discovers every native case via
/// JNI and reports it as an individual JUnit test, so Android Studio, Gradle
/// and the JUnit XML results parse each native case under its own name with
/// its own failure output.
///
/// @note Follows Android’s official on-device native testing guidance:
///       https://developer.android.com/ndk/guides/test-native-libraries
///       https://developer.android.com/training/testing/unit-testing/instrumented-unit-tests
///
/// @see DoctestRunner
/// @see https://developer.android.com/ndk/guides/test-native-libraries
/// @see https://developer.android.com/training/testing/unit-testing/instrumented-unit-tests
/// @see gradle task :app:connectedDebugAndroidTest
@RunWith(DoctestRunner.class)
public final class NativeDoctestTests {

    static {
        assumeTrue("Must run on device", !Build.FINGERPRINT.equals("robolectric"));
        System.loadLibrary("tests");
    }

    /// @return the names of all registered doctest cases.
    static native String[] getTestNames();

    /// Runs a single doctest case by its exact registered name.
    ///
    /// @return null when the case passes; the captured doctest console report
    ///         when it fails. The report becomes the JUnit failure message, so
    ///         native assertion details survive into the test reports instead
    ///         of being lost to logcat.
    static native String runTest(String name);
}
