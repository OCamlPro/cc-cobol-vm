use std::process::Command;

mod http_static_server;

fn main() -> anyhow::Result<()> {
    let mut bash_cmd = Command::new("./scripts/vm-start.sh").spawn()?;

    let tokio_rt = tokio::runtime::Runtime::new()?;
    tokio_rt.block_on(http_static_server::main())?;

    let bash_success = bash_cmd.wait()?;

    if !bash_success.success() {
        anyhow::bail!("Launchim vm start failed.")
    }

    Ok(())
}
