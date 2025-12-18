import time

from websockets.sync.client import connect

from locust import User, between, events, task


class WebSocketUser(User):
    host = "ws://localhost:4001"
    wait_time = between(0.5, 2)  # Users wait 0.5-2 seconds between tasks

    def on_start(self):
        """Called when a virtual user starts."""
        # The host is passed via the --host flag when running Locust
        if not self.host:
            raise ValueError("Host must be specified (e.g., via --host)")
        self.ws_url = f"{self.host.rstrip('/')}/echo"
        self.connect()

    def connect(self):
        """Establish the WebSocket connection."""
        try:
            self.ws = connect(self.ws_url, timeout=10)
            events.request.fire(
                request_type="WebSocket",
                name="connect",
                response_time=0,
                response_length=0,
                exception=None,
            )
        except Exception as e:
            events.request.fire(
                request_type="WebSocket",
                name="connect",
                response_time=0,
                response_length=0,
                exception=e,
            )
            raise e

    def on_stop(self):
        """Called when a virtual user stops."""
        if hasattr(self, "ws"):
            try:
                self.ws.close()
            except Exception as e:
                events.request.fire(
                    request_type="WebSocket",
                    name="disconnect",
                    response_time=0,
                    response_length=0,
                    exception=e,
                )
                raise e

    @task
    def send_and_echo(self):
        """Main task: send a message and wait for the echo."""
        message = f"Hello from Locust at {time.time()}"
        self._send_receive(message)

    def _send_receive(self, message):
        """Helper to send a message and record the round-trip."""
        start_time = time.time()
        try:
            self.ws.send(message)
            echo = self.ws.recv()  # Wait for the server's echo

            # Record a successful request
            response_time = int((time.time() - start_time) * 1000)  # in ms
            events.request.fire(
                request_type="WebSocket",
                name="echo",
                response_time=response_time,
                response_length=len(echo),
                exception=None,
                context={"message": message},
            )

        except Exception as e:
            response_time = int((time.time() - start_time) * 1000)
            events.request.fire(
                request_type="WebSocket",
                name="echo",
                response_time=response_time,
                response_length=0,
                exception=e,
            )
            # Reconnect on error
            self.connect()
