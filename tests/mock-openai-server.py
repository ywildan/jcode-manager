#!/usr/bin/env python3
"""Mock OpenAI-compatible server buat acceptance test jcode.

Log tiap request (path + Authorization header) ke path yang dikasih di argv[2].
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG = sys.argv[2] if len(sys.argv) > 2 else "/var/tmp/jcm-mock.log"


def log(line):
    with open(LOG, "a") as fh:
        fh.write(line + "\n")


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def _send(self, code, body, ctype="application/json"):
        payload = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        log("GET %s auth=%s" % (self.path, self.headers.get("Authorization")))
        if self.path.rstrip("/").endswith("/models"):
            self._send(200, json.dumps({
                "object": "list",
                "data": [{"id": "mock-model", "object": "model", "owned_by": "mock"}],
            }))
        else:
            self._send(404, json.dumps({"error": {"message": "not found"}}))

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length).decode("utf-8", "replace")
        try:
            payload = json.loads(raw or "{}")
        except ValueError:
            payload = {}
        log("POST %s auth=%s stream=%s model=%s" % (self.path, self.headers.get("Authorization"), payload.get("stream"), payload.get("model")))

        if self.path.endswith("/responses"):
            self._send(200, json.dumps({
                "id": "resp_mock",
                "object": "response",
                "created_at": 1,
                "model": payload.get("model", "mock-model"),
                "status": "completed",
                "output": [{
                    "id": "msg_mock",
                    "type": "message",
                    "role": "assistant",
                    "status": "completed",
                    "content": [{"type": "output_text", "text": "PONG", "annotations": []}],
                }],
                "usage": {"input_tokens": 1, "output_tokens": 1, "total_tokens": 2},
            }))
            return

        if self.path.endswith("/chat/completions"):
            chunk = {
                "id": "chatcmpl-mock",
                "object": "chat.completion.chunk",
                "created": 1,
                "model": payload.get("model", "mock-model"),
                "choices": [{"index": 0, "delta": {"role": "assistant", "content": "PONG"}, "finish_reason": None}],
            }
            stop = {
                "id": "chatcmpl-mock",
                "object": "chat.completion.chunk",
                "created": 1,
                "model": payload.get("model", "mock-model"),
                "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
            }
            body = "data: %s\n\ndata: %s\n\ndata: [DONE]\n\n" % (json.dumps(chunk), json.dumps(stop))
            self._send(200, body, "text/event-stream")
            return

        self._send(404, json.dumps({"error": {"message": "not found"}}))


if __name__ == "__main__":
    port = int(sys.argv[1])
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
