use std::process::Command;

fn main() -> std::io::Result<()> {
    let mut bash_cmd = Command::new("./scripts/vm-start.sh").spawn()?;

    let bash_success = bash_cmd.wait()?;

    if !bash_success.success() {
        panic!("Launchim vm start failed.")
    }

    Ok(())
}
