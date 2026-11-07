import 'package:dcm/backend/services/app_watchdog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires a UI frame before its startup deadline', () {
    final started = DateTime(2026, 1, 1);

    expect(
      AppWatchdogHealthPolicy.isUiUnresponsive(
        now: started.add(const Duration(seconds: 119)),
        childStartedAt: started,
        lastUiFrameAt: null,
      ),
      isFalse,
    );
    expect(
      AppWatchdogHealthPolicy.isUiUnresponsive(
        now: started.add(AppWatchdogHealthPolicy.startupGrace),
        childStartedAt: started,
        lastUiFrameAt: null,
      ),
      isTrue,
    );
  });

  test('detects missing UI frames and exempts an explicit user exit', () {
    final now = DateTime(2026, 1, 1, 0, 1);
    expect(
      AppWatchdogHealthPolicy.isUiUnresponsive(
        now: now,
        childStartedAt: now.subtract(const Duration(minutes: 2)),
        lastUiFrameAt: now.subtract(AppWatchdogHealthPolicy.uiHangTimeout),
      ),
      isTrue,
    );
    expect(
      AppWatchdogHealthPolicy.shouldRestartAfterExit(1),
      isTrue,
    );
    expect(
      AppWatchdogHealthPolicy.shouldRestartAfterExit(
        1,
        userRequestedExit: true,
      ),
      isFalse,
    );
    expect(
      AppWatchdogHealthPolicy.shouldRestartAfterExit(0),
      isFalse,
    );
  });

  test('backs off exponentially and caps restart delay', () {
    final policy = AppWatchdogRestartPolicy();

    expect(policy.recordFailure(Duration.zero), const Duration(seconds: 3));
    expect(policy.recordFailure(Duration.zero), const Duration(seconds: 6));
    expect(policy.recordFailure(Duration.zero), const Duration(seconds: 12));
    expect(policy.recordFailure(Duration.zero), const Duration(seconds: 24));
    expect(policy.recordFailure(Duration.zero), const Duration(seconds: 48));
    expect(policy.recordFailure(Duration.zero), const Duration(minutes: 1));
    expect(policy.recordFailure(Duration.zero), const Duration(minutes: 1));
  });

  test('resets backoff after the child runs stably', () {
    final policy = AppWatchdogRestartPolicy();

    policy.recordFailure(Duration.zero);
    policy.recordFailure(Duration.zero);
    expect(
      policy.recordFailure(AppWatchdogRestartPolicy.stableRuntime),
      const Duration(seconds: 3),
    );
  });
}
