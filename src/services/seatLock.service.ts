import { getCacheClient } from '../config/redis';

// Lua script for Atomic Multi-Seat Hold:
// If ANY seat is already taken/held, abort immediately and lock NONE of them.
// If ALL seats are free, lock all of them with the specified TTL.
const ACQUIRE_SEATS_LUA = `
local ttl = tonumber(ARGV[#ARGV])
local user_id = ARGV[1]

for i=1, #KEYS do
  if redis.call('EXISTS', KEYS[i]) == 1 then
    return 0 -- Conflict: at least one seat is already held
  end
end

for i=1, #KEYS do
  redis.call('SET', KEYS[i], user_id, 'EX', ttl)
end

return 1 -- Success: all seats locked atomically
`;

// Lua script to safely release seats only if held by the requesting user
const RELEASE_SEATS_LUA = `
local user_id = ARGV[1]
local released = 0

for i=1, #KEYS do
  if redis.call('GET', KEYS[i]) == user_id then
    redis.call('DEL', KEYS[i])
    released = released + 1
  end
end

return released
`;

export class SeatLockService {
  private static getKey(showId: number, seatId: number): string {
    return `lock:show:${showId}:seat:${seatId}`;
  }

  /**
   * Atomically acquire temporary holds on multiple seats for a show.
   * @param showId Show ID
   * @param seatIds Array of Seat IDs
   * @param userId User identifier holding the seats
   * @param ttlSeconds Lock duration in seconds (default 600s / 10 minutes)
   */
  static async acquireSeatHolds(
    showId: number,
    seatIds: number[],
    userId: string,
    ttlSeconds: number = 600
  ): Promise<boolean> {
    if (seatIds.length === 0) return true;

    const redis = await getCacheClient();
    const sortedSeatIds = [...seatIds].sort((a, b) => a - b); // Prevent deadlock ordering
    const keys = sortedSeatIds.map((seatId) => this.getKey(showId, seatId));

    const result = await redis.eval(
      ACQUIRE_SEATS_LUA,
      keys.length,
      ...keys,
      userId,
      ttlSeconds
    );

    return result === 1;
  }

  /**
   * Release seat holds for a given user.
   */
  static async releaseSeatHolds(
    showId: number,
    seatIds: number[],
    userId: string
  ): Promise<number> {
    if (seatIds.length === 0) return 0;

    const redis = await getCacheClient();
    const keys = seatIds.map((seatId) => this.getKey(showId, seatId));

    const released = await redis.eval(
      RELEASE_SEATS_LUA,
      keys.length,
      ...keys,
      userId
    );

    return Number(released);
  }

  /**
   * Check if a specific seat is currently held.
   */
  static async isSeatHeld(showId: number, seatId: number): Promise<boolean> {
    const redis = await getCacheClient();
    const val = await redis.get(this.getKey(showId, seatId));
    return val !== null;
  }
}
