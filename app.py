from flask import Flask, render_template, request, Response, stream_with_context
import anthropic
import os
import json

app = Flask(__name__)

SYSTEM_PROMPT = (
    "You are an AI and tech trends research agent. When given a topic, you research it "
    "and return a concise bullet summary. Always structure your response as: "
    "What it is — one sentence explanation. "
    "Why it matters — 2-3 bullets on current relevance. "
    "Key players — 2-3 bullets on who is leading this trend. "
    "What to watch — 2-3 bullets on what's coming next. "
    "Keep each bullet under 15 words. Be direct, no fluff. "
    "Focus on practical implications for someone building an AI business."
)

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/research", methods=["POST"])
def research():
    data = request.get_json()
    topic = (data or {}).get("topic", "").strip()
    if not topic:
        return {"error": "No topic provided"}, 400

    def generate():
        try:
            client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
            with client.messages.stream(
                model="claude-opus-4-6",
                max_tokens=1024,
                system=SYSTEM_PROMPT,
                messages=[{"role": "user", "content": f"Research this topic: {topic}"}],
            ) as stream:
                for text in stream.text_stream:
                    yield f"data: {json.dumps({'text': text})}\n\n"
            yield "data: [DONE]\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return Response(
        stream_with_context(generate()),
        mimetype="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
