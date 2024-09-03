use std::{
    io::{Read, Write},
    net::{TcpListener, TcpStream},
    process::Command,
};

fn handle_client(mut stream: TcpStream) {
    let mut buffer = [0; 512];
    match stream.read(&mut buffer) {
        Ok(_) => {
            println!("Received: {}", String::from_utf8_lossy(&buffer[..]));
            stream.write(b"HTTP/1.1 200 OK\r\n\r\n").unwrap();
        }
        Err(e) => println!("Failed to receive data: {}", e),
    }
}
fn main() -> anyhow::Result<()> {
    // let status = Command::new("git")
    //     .args(&["clone", "https://github.com/OCamlPro/cc-cobol-vm"])
    //     .status()
    //     .expect("Failed to clone repository");

    // if !status.success() {
    //     anyhow::bail!("Git clone failed.");
    // }

    // env::set_current_dir("cc-cobol-vm")?;

    let mut bash_cmd = Command::new("./scripts/vm-start.sh").spawn()?;

    let listener = TcpListener::bind("0.0.0.0:8080")?;

    for stream in listener.incoming() {
        let stream = stream?;
        std::thread::spawn(move || handle_client(stream));
    }

    let bash_success = bash_cmd.wait()?;

    if !bash_success.success() {
        anyhow::bail!("Launchim vm start failed.")
    }

    Ok(())
}
