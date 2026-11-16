const RIDE_EDIT_LOCK_WINDOW_MS = 60 * 60 * 1000

const getRideStartTime = (date: string, time: string) => new Date(`${date}T${time}`).getTime()

export const hasRideStarted = (date: string, time: string, now = Date.now()) =>
  getRideStartTime(date, time) <= now

export const hasRideEnded = (date: string, time: string, now = Date.now()) =>
  getRideStartTime(date, time) + RIDE_EDIT_LOCK_WINDOW_MS <= now

export const isRideEditLocked = (date: string, time: string, now = Date.now()) =>
  getRideStartTime(date, time) <= now + RIDE_EDIT_LOCK_WINDOW_MS
