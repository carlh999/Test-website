from flask import Flask, render_template, request, Response, stream_with_context
import anthropic
import os
import json

app = Flask(__name__)

NEXUS_PROMPT = (
    "You are an AI and tech trends research agent. When given a topic, you research it "
    "and return a concise bullet summary. Always structure your response as: "
    "What it is — one sentence explanation. "
    "Why it matters — 2-3 bullets on current relevance. "
    "Key players — 2-3 bullets on who is leading this trend. "
    "What to watch — 2-3 bullets on what's coming next. "
    "Keep each bullet under 15 words. Be direct, no fluff. "
    "Focus on practical implications for someone building an AI business."
)

TRIAGE_PROMPT = (
    "You are a market signal analyst. You receive a research brief and must decide whether "
    "the topic shows strong enough market signals to warrant competitive intelligence analysis. "
    "Evaluate the brief for: active development and investment, growing market demand, "
    "multiple players competing, and clear monetization potential. "
    "Respond with ONLY a JSON object, nothing else: "
    '{"run_scout": true, "reason": "one sentence why"} or '
    '{"run_scout": false, "reason": "one sentence why"}. '
    "Run scout if: strong market signals, active development, growing investment, emerging opportunity. "
    "Skip scout if: weak signals, declining interest, saturated/dead market, purely academic topic, "
    "or the topic is too vague to analyse competitively."
)

SCOUT_PROMPT = (
    "You are SCOUT, a competitive intelligence agent. You receive a research brief about a topic "
    "and your job is to analyze the competitive landscape. Always structure your response as: "
    "Who is building — 3-5 bullets naming specific companies/products in this space with one-line descriptions. "
    "What they charge — 3-5 bullets on pricing models, tiers, and revenue strategies you know about. "
    "Where the gap is — 3-5 bullets identifying underserved niches, missing features, or market opportunities. "
    "Keep each bullet under 20 words. Be specific — name real companies and real prices where possible. "
    "If you don't know exact pricing, say so and estimate the range. "
    "Focus on actionable intelligence for someone looking to compete or enter this market."
)

PROPERTY_SYSTEM_PROMPT = (
    "You are PROPLINK AI, a property management assistant. You have access to the following "
    "dashboard data for a 14-unit apartment building:\n\n"
    "TENANTS (10 occupied units):\n"
    "- Unit 101: Maria Santos, $1,400/mo, Rent PAID, 0 maintenance requests\n"
    "- Unit 102: James Chen, $1,550/mo, Rent OVERDUE, 2 maintenance requests (leaking kitchen faucet [HIGH], broken window latch bedroom [MEDIUM])\n"
    "- Unit 103: Aisha Patel, $1,200/mo, Rent PAID, 0 maintenance requests\n"
    "- Unit 201: David Kim, $1,600/mo, Rent PAID, 1 maintenance request (HVAC filter replacement [LOW])\n"
    "- Unit 202: Sarah Johnson, $1,400/mo, Rent OVERDUE, 0 maintenance requests\n"
    "- Unit 203: Omar Hassan, $1,350/mo, Rent PAID, 1 maintenance request (dishwasher not draining [MEDIUM])\n"
    "- Unit 301: Emily Turner, $1,750/mo, Rent PAID, 0 maintenance requests\n"
    "- Unit 302: Lucas Rivera, $1,400/mo, Rent OVERDUE, 3 maintenance requests (bathroom ceiling water stain [HIGH], front door deadbolt jammed [HIGH], garbage disposal broken [MEDIUM])\n"
    "- Unit 303: Nina Volkov, $1,500/mo, Rent PAID, 0 maintenance requests\n"
    "- Unit 401: Ryan McCarthy, $1,600/mo, Rent PAID, 1 maintenance request (intercom buzzer not working [LOW])\n\n"
    "VACANT UNITS (4):\n"
    "- Unit 104: 1BR, asking $1,300/mo\n"
    "- Unit 204: 2BR, asking $1,650/mo\n"
    "- Unit 304: 1BR, asking $1,350/mo\n"
    "- Unit 402: 2BR, asking $1,700/mo\n\n"
    "SUMMARY:\n"
    "- Total rent collected: $14,200 (7 paid tenants)\n"
    "- Total overdue: $3,950 (3 tenants: James Chen $1,550, Sarah Johnson $1,400, Lucas Rivera $1,400)\n"
    "- Open maintenance requests: 8 total (3 HIGH, 3 MEDIUM, 2 LOW)\n"
    "- Occupancy rate: 71% (10/14)\n\n"
    "RULES:\n"
    "- Answer using ONLY the tenant data above. Do not invent data.\n"
    "- Be concise and professional. Get to the point immediately.\n"
    "- No emojis. No markdown formatting. Plain text only.\n"
    "- Do not ask follow-up questions.\n"
    "- Do not offer to help with anything else.\n"
    "- Do not add disclaimers or caveats.\n"
    "- Stop after answering the question. Do not continue."
)


def _stream_agent(system_prompt, user_message, messages=None):
    """Stream a response from Claude with the given system prompt."""
    def generate():
        try:
            client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
            msg_list = messages if messages else [{"role": "user", "content": user_message}]
            with client.messages.stream(
                model="claude-sonnet-4-6",
                max_tokens=1024,
                system=system_prompt,
                messages=msg_list,
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


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/property")
def property_page():
    return render_template("property.html")


@app.route("/property/chat", methods=["POST"])
def property_chat():
    data = request.get_json()
    messages = (data or {}).get("messages", [])
    if not messages:
        return {"error": "No messages provided"}, 400
    return _stream_agent(PROPERTY_SYSTEM_PROMPT, messages[-1]["content"], messages=messages)


@app.route("/research", methods=["POST"])
def research():
    data = request.get_json()
    topic = (data or {}).get("topic", "").strip()
    if not topic:
        return {"error": "No topic provided"}, 400
    return _stream_agent(NEXUS_PROMPT, f"Research this topic: {topic}")


@app.route("/triage", methods=["POST"])
def triage():
    data = request.get_json()
    topic = (data or {}).get("topic", "").strip()
    nexus_brief = (data or {}).get("nexus_brief", "").strip()
    if not topic or not nexus_brief:
        return {"error": "Missing topic or brief"}, 400

    try:
        client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
        resp = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=128,
            system=TRIAGE_PROMPT,
            messages=[{"role": "user", "content": f"Topic: {topic}\n\nBrief:\n{nexus_brief}"}],
        )
        text = resp.content[0].text.strip()
        return json.loads(text)
    except Exception as e:
        # If triage fails, default to running scout
        return {"run_scout": True, "reason": f"Triage error: {str(e)}"}


@app.route("/scout", methods=["POST"])
def scout():
    data = request.get_json()
    topic = (data or {}).get("topic", "").strip()
    nexus_brief = (data or {}).get("nexus_brief", "").strip()
    if not topic:
        return {"error": "No topic provided"}, 400
    user_message = (
        f"Topic: {topic}\n\n"
        f"Here is the NEXUS research brief on this topic:\n\n{nexus_brief}\n\n"
        f"Now provide your competitive intelligence analysis."
    )
    return _stream_agent(SCOUT_PROMPT, user_message)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=False)
