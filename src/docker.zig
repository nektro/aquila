const extras = @import("extras");

pub fn amInside() !bool {
    return try extras.doesFileExist(null, "/.dockerenv");
}
