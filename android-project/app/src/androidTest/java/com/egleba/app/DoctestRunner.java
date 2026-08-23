package com.egleba.app;

import org.junit.runner.Description;
import org.junit.runner.notification.RunNotifier;
import org.junit.runners.ParentRunner;
import org.junit.runners.model.InitializationError;
import org.junit.runners.model.Statement;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/// JUnit4 runner that bridges native doctest cases into Android's
/// instrumentation pipeline, one JUnit test per doctest case.
///
/// Replaces the previous Parameterized-runner bridge, which did not parse
/// correctly:
///   1. Every case ran as `runNative[<name>]` — a single synthetic method
///      name, so results could not be read or filtered per case.
///   2. Raw doctest names went straight into the line-based
///      INSTRUMENTATION_STATUS protocol, where a name containing a newline or
///      a control character corrupts ddmlib's InstrumentationResultParser.
///   3. The native side ran doctest with no-exitcode, which forces
///      Context::run() to return 0 even for failing cases — every test was
///      reported as passed.
///
/// Here each case gets a display name sanitized for the status protocol and
/// for XML consumers, and a failing case surfaces its full doctest report as
/// the AssertionError message (the `<failure>` element in the JUnit XML).
public final class DoctestRunner extends ParentRunner<DoctestRunner.NativeTestCase> {

    /// A discovered native case: the JUnit-facing description plus the exact
    /// doctest name needed to run it.
    static final class NativeTestCase {
        final Description description;
        final String nativeName;

        NativeTestCase(final Description description, final String nativeName) {
            this.description = description;
            this.nativeName = nativeName;
        }
    }

    private final List<NativeTestCase> children;

    public DoctestRunner(final Class<?> testClass) throws InitializationError {
        super(testClass);

        final String[] names = Objects.requireNonNull(
                NativeDoctestTests.getTestNames(),
                "Native test names must not be null — check that libtests is loaded and exports a valid test suite.");
        if (names.length == 0) {
            throw new InitializationError("No native doctest cases discovered in libtests");
        }

        final List<NativeTestCase> cases = new ArrayList<>(names.length);
        final Map<String, Integer> displayNameCounts = new HashMap<>();
        for (final String name : names) {
            String displayName = toDisplayName(name);
            final int seen = displayNameCounts.merge(displayName, 1, Integer::sum);
            if (seen > 1) {
                // Two native names sanitized to the same display name — keep
                // the JUnit descriptions unique so reports never merge them.
                displayName = displayName + " [" + seen + "]";
            }
            cases.add(new NativeTestCase(
                    Description.createTestDescription(testClass, displayName), name));
        }
        children = Collections.unmodifiableList(cases);
    }

    @Override
    protected List<NativeTestCase> getChildren() {
        return children;
    }

    @Override
    protected Description describeChild(final NativeTestCase child) {
        return child.description;
    }

    @Override
    protected void runChild(final NativeTestCase child, final RunNotifier notifier) {
        runLeaf(new Statement() {
            @Override
            public void evaluate() {
                final String report = NativeDoctestTests.runTest(child.nativeName);
                if (report != null) {
                    throw new AssertionError(
                            "Native doctest case failed: " + child.nativeName + '\n' + report);
                }
            }
        }, child.description, notifier);
    }

    /// Makes a doctest case name safe for the line-based instrumentation
    /// status protocol and for XML 1.0 test reports: newlines and carriage
    /// returns would corrupt ddmlib's key=value parsing, and the remaining
    /// control characters are not representable in XML.
    private static String toDisplayName(final String nativeName) {
        final StringBuilder sanitized = new StringBuilder(nativeName.length());
        for (int i = 0; i < nativeName.length(); ++i) {
            final char c = nativeName.charAt(i);
            if (c == '\n' || c == '\r') {
                sanitized.append(' ');
            } else if (Character.isISOControl(c)) {
                sanitized.append('?');
            } else {
                sanitized.append(c);
            }
        }
        final String trimmed = sanitized.toString().trim();
        return trimmed.isEmpty() ? "<unnamed>" : trimmed;
    }
}
