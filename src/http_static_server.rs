//! Run with
//!
//! ```not_rust
//! cargo run -p example-static-file-server
//! ```

// use axum::Router;
// use std::net::SocketAddr;
// use tower_http::{services::ServeDir, trace::TraceLayer};
// use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

// pub async fn main() -> anyhow::Result<()> {
//     tracing_subscriber::registry()
//         .with(
//             tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
//                 format!("{}=trace,tower_http=trace", env!("CARGO_CRATE_NAME")).into()
//             }),
//         )
//         .with(tracing_subscriber::fmt::layer())
//         .init();
//     serve(using_serve_dir(), 8080).await
// }

// fn using_serve_dir() -> Router {
//     Router::new().route_service("/FSB", dbg!(ServeDir::new("FSB")))
// }

// async fn serve(app: Router, port: u16) -> anyhow::Result<()> {
//     let addr = SocketAddr::from(([0, 0, 0, 0], port));
//     let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
//     tracing::debug!("listening on {}", listener.local_addr().unwrap());
//     axum::serve(listener, app.layer(TraceLayer::new_for_http())).await?;
//     Ok(())
// }

use std::path::PathBuf;

use axum::response::IntoResponse;

pub async fn main() -> anyhow::Result<()> {
    // Set up routes
    let app = axum::Router::new()
        .route("/*path", axum::routing::get(dir_browser_wrap))
        .route("/", axum::routing::get(dir_browser_wrap));

    // Define the address for the server to listen on
    let addr = std::net::SocketAddr::from(([0, 0, 0, 0], 8080));

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    tracing::debug!("listening on {}", listener.local_addr().unwrap());
    axum::serve(
        listener,
        app.layer(tower_http::trace::TraceLayer::new_for_http()),
    )
    .await?;
    Ok(())
}

async fn dir_browser_wrap(
    path: Option<axum::extract::Path<String>>,
) -> axum::response::Response<axum::body::Body> {
    let path = match path {
        Some(axum::extract::Path(path)) => path,
        None => Default::default(),
    };
    dir_browser(path)
        .await
        .map_err(|e| e.to_string())
        .into_response()
}

async fn dir_browser(path: String) -> anyhow::Result<axum::response::Response<axum::body::Body>> {
    let mut full_path = PathBuf::from(".");
    full_path.push(&path);
    dbg!(&full_path);
    if full_path.is_dir() {
        let entries = std::fs::read_dir(full_path).map_err(|_| {
            std::io::Error::new(std::io::ErrorKind::NotFound, "Directory not found")
        })?;
        let mut html = String::new();
        html.push_str("<ul>");
        for entry in entries {
            let entry = entry.map_err(|_| {
                std::io::Error::new(std::io::ErrorKind::NotFound, "Failed to read entry")
            })?;
            let file_name = entry.file_name().into_string().unwrap();
            let entry_path = entry.path();
            let suffix = if entry_path.is_dir() { "/" } else { "" };

            html.push_str(&format!(
                "<li><a href=\"/{}{}\">{}{}</a></li>",
                entry_path.display(),
                suffix,
                file_name,
                suffix,
            ));
        }
        html.push_str("</ul>");
        Ok(axum::response::Html(html).into_response())
    } else {
        let file = tokio::fs::File::open(full_path).await.unwrap();
        let stream = tokio_util::io::ReaderStream::new(file);
        Ok(axum::body::Body::from_stream(stream).into_response())
    }
}
