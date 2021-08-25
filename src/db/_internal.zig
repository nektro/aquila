const std = @import("std");
const zorm = @import("zorm");

pub const Engine = zorm.engine(.sqlite3);
pub var db: Engine = undefined;
