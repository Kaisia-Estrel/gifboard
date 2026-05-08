use smithay_client_toolkit::reexports::client::{
    protocol::{wl_data_device_manager::WlDataDeviceManager, wl_data_source::WlDataSource},
    Connection, QueueHandle,
};
use smithay_client_toolkit::seat::SeatHandler;
use smithay_client_toolkit::seat::pointer::PointerEvent;
use smithay_client_toolkit::seat::Capability;
use smithay_client_toolkit::WaylandSource;

use std::sync::Arc;

const FILE_URI: &str =
    "file:///tmp/tmp.NM2fIFxySp-kaname-madoka.webp";

struct App;

impl SeatHandler for App {
    fn new_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: smithay_client_toolkit::seat::Seat) {}

    fn new_capability(
        &mut self,
        conn: &Connection,
        qh: &QueueHandle<Self>,
        seat: smithay_client_toolkit::seat::Seat,
        capability: Capability,
    ) {
        if capability == Capability::Pointer {
            let dnd_manager = conn
                .instantiate_global::<WlDataDeviceManager>(1)
                .expect("data device manager");

            let data_device = dnd_manager.get_data_device(&seat);

            let source = dnd_manager.create_data_source();

            // advertise MIME types
            source.offer("text/uri-list".into());

            // provide data when requested
            source.quick_assign(|source, event, _| {
                if let smithay_client_toolkit::reexports::client::protocol::wl_data_source::Event::Send {
                    mime_type,
                    fd,
                } = event
                {
                    if mime_type == "text/uri-list" {
                        use std::io::Write;
                        let mut file = unsafe { std::fs::File::from_raw_fd(fd) };
                        let _ = file.write_all(FILE_URI.as_bytes());
                    }
                }

                if let smithay_client_toolkit::reexports::client::protocol::wl_data_source::Event::Cancelled = event
                {
                    std::process::exit(0);
                }
            });

            // Start drag (NULL surface = no window surface needed here in minimal form)
            data_device.start_drag(
                Some(&source),
                None::<&smithay_client_toolkit::reexports::client::protocol::wl_surface::WlSurface>,
                None,
            );

            println!("Drag started with: {FILE_URI}");
        }
    }

    fn remove_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: smithay_client_toolkit::seat::Seat) {}
    // fn update_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: smithay_client_toolkit::seat::Seat) {}

    fn seat_state(&mut self) -> &mut smithay_client_toolkit::seat::SeatState {
        todo!()
    }

    fn remove_capability(
        &mut self,
        conn: &Connection,
        qh: &QueueHandle<Self>,
        seat: wayland_client::protocol::wl_seat::WlSeat,
        capability: Capability,
    ) {
        todo!()
    }
}

fn main() {
    let conn = Connection::connect_to_env().unwrap();
    let display = conn.display();
    let mut event_queue = conn.new_event_queue();
    let qh = event_queue.handle();

    let mut app = App;

    WaylandSource::new(conn.clone(), event_queue)
        .insert_idle(move |conn| {
            let _ = conn;
        })
        .expect("init");

    loop {
        event_queue.blocking_dispatch(&mut app).unwrap();
    }
}
