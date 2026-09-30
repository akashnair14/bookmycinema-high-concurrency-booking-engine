import { SeatLockService } from '../src/services/seatLock.service';

async function runConcurrencyProof() {
  console.log('===============================================================');
  console.log('TEST 1: HIGH-CONCURRENCY CONTESTED SEATS (RACE CONDITION CHECK)');
  console.log('===============================================================');

  const showId = 1;
  const targetSeatIds = [3, 4]; // 2 seats contested by 100 users simultaneously
  const totalConcurrentUsers = 100;

  console.log(`[Test 1] Simulating ${totalConcurrentUsers} concurrent users competing for seats [${targetSeatIds.join(', ')}]...`);

  const startTime = Date.now();

  // Fire 100 asynchronous lock requests simultaneously
  const attempts = Array.from({ length: totalConcurrentUsers }, (_, idx) => {
    const userId = `concurrent_user_${idx + 1}`;
    return SeatLockService.acquireSeatHolds(showId, targetSeatIds, userId, 600)
      .then((acquired) => ({ userId, acquired }));
  });

  const results = await Promise.all(attempts);
  const durationMs = Date.now() - startTime;

  const successfulHold = results.filter((r) => r.acquired);
  const rejectedHolds = results.filter((r) => !r.acquired);

  console.log(`⏱️ Contested seat test finished in ${durationMs}ms`);
  console.log(`✅ Successful holds: ${successfulHold.length}`);
  console.log(`❌ Rejected holds (Conflicts avoided): ${rejectedHolds.length}`);

  if (successfulHold.length === 1 && rejectedHolds.length === totalConcurrentUsers - 1) {
    console.log(`🏆 PASSED: Exactly 1 user (${successfulHold[0].userId}) acquired the seats!`);
    console.log('🛡️ ZERO DOUBLE-BOOKINGS. Race condition successfully eliminated.\n');
  } else {
    console.error('💥 FAILED: Double booking detected!');
    process.exit(1);
  }

  const winningUser = successfulHold[0].userId;

  console.log('===============================================================');
  console.log('TEST 2: INDEPENDENT SEATS CONCURRENCY (ZERO FALSE CONFLICTS)');
  console.log('===============================================================');

  // 10 different users booking 10 completely different seats simultaneously
  const independentSeatIds = [11, 12, 13, 14, 15, 16, 17, 18, 19, 20];
  console.log(`[Test 2] Simulating 10 users booking 10 non-overlapping seats concurrently...`);

  const independentAttempts = independentSeatIds.map((seatId, idx) => {
    const userId = `independent_user_${idx + 1}`;
    return SeatLockService.acquireSeatHolds(showId, [seatId], userId, 600)
      .then((acquired) => ({ userId, seatId, acquired }));
  });

  const independentResults = await Promise.all(independentAttempts);
  const allIndependentPassed = independentResults.every((r) => r.acquired);

  if (allIndependentPassed) {
    console.log(`✅ All ${independentResults.length} non-conflicting seat holds succeeded concurrently with 0 false conflicts.\n`);
  } else {
    console.error('💥 FAILED: Independent seat booking had unexpected false conflicts!');
    process.exit(1);
  }

  console.log('===============================================================');
  console.log('TEST 3: SAFE HOLD RELEASE (AUTHORIZATION ENFORCEMENT)');
  console.log('===============================================================');

  console.log(`[Test 3A] Unauthorized user attempting to release seats held by ${winningUser}...`);
  const unauthorizedReleased = await SeatLockService.releaseSeatHolds(showId, targetSeatIds, 'attacker_user_999');
  if (unauthorizedReleased === 0) {
    console.log('🛡️ PASSED: Unauthorized release rejected. Seats remain protected.');
  } else {
    console.error('💥 FAILED: Unauthorized user was able to release held seats!');
    process.exit(1);
  }

  console.log(`[Test 3B] Legitimate user (${winningUser}) releasing held seats...`);
  const legitReleased = await SeatLockService.releaseSeatHolds(showId, targetSeatIds, winningUser);
  if (legitReleased === targetSeatIds.length) {
    console.log(`✅ PASSED: Legitimate owner released ${legitReleased} seat(s).`);
  } else {
    console.error('💥 FAILED: Legitimate user failed to release held seats!');
    process.exit(1);
  }

  console.log(`[Test 3C] Another user re-acquiring the now-available seats...`);
  const reacquired = await SeatLockService.acquireSeatHolds(showId, targetSeatIds, 'next_waiting_user', 600);
  if (reacquired) {
    console.log('✅ PASSED: Released seats immediately became available for the next user.\n');
  } else {
    console.error('💥 FAILED: Seats remained locked after legitimate release!');
    process.exit(1);
  }

  console.log('===============================================================');
  console.log('🏆 ALL HIGH-CONCURRENCY RIGOR TESTS PASSED PERFECTLY!');
  console.log('===============================================================');
  process.exit(0);
}

runConcurrencyProof().catch((err) => {
  console.error('Error during concurrency test:', err);
  process.exit(1);
});
