// Entry point for the public status page. It loads only what that page uses:
// local-time converts the server-rendered UTC timestamps to the visitor's zone.
import LocalTime from "local-time"

LocalTime.start()
