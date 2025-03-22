// This module is a facade that re-exports the functionality from the refactored modules
// to maintain backward compatibility and provide a simple interface

pub use crate::scripts::collector::collect_scripts;
pub use crate::scripts::display::list_scripts;
pub use crate::scripts::models::{PathNames, ScriptInfo};
pub use crate::scripts::runner::run_scripts;
