import time

import websocket  # You'll need to install this: pip install websocket-client
from locust import User, events, task
from locust.user.wait_time import constant


class WebSocketUser(User):
    host = "ws://localhost:4001/echo"  # Your WebSocket server URL
    wait_time = constant(1)  # Simulate user think time

    def on_start(self):
        if not self.host:
            return
        self.ws = websocket.create_connection(self.host)
        print(f"WebSocket connected for user {self.environment.runner.user_count}")

    @task
    def send_and_receive_message(self):
        start_time = time.time()
        try:
            message = "Hello from Locust!"
            self.ws.send(message)
            received_message = self.ws.recv()

            events.request.fire(
                request_type="WebSocket",
                name="/ws/send_receive",
                response_time=(time.time() - start_time) * 1000,
                response_length=len(received_message),
                exception=None,
            )
            print(f"Received: {received_message}")

        except Exception as e:
            events.request.fire(
                request_type="WebSocket",
                name="/ws/send_receive",
                response_time=(time.time() - start_time) * 1000,
                response_length=0,
                exception=e,
            )
            print(f"Error during WebSocket interaction: {e}")

    def on_stop(self):
        self.ws.close()
        print(f"WebSocket closed for user {self.environment.runner.user_count}")
