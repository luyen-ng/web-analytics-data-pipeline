from fastapi import FastAPI, HTTPException, Header, status, JsonResponse, request
# from pydantic import BaseModel
from dateutil import parser
import os, time, random, uuid, threading
from generator import DataGenerator

API_KEY = os.environ["API_KEY"]
RATE = int(os.environ.get("API_RATE_LIMIT_PER_MIN", "60"))  # requests per minute
WINDOW = 60  # seconds

app = FastAPI()
data = DataGenerator()

#threading lock for rate limiting
lock = threading.Lock()
last_reset = time.time()
counter = 0

def check_rate_limit():
    global last_reset, counter
    with lock:
        now = time.time()
        if now - last_reset > WINDOW:
            last_reset = now
            counter = 0
        if counter >= RATE:
            return False
        counter += 1
        return True
    
def require_auth(authorization: str = Header(...)):
    if not authorization.startswith("Bearer ") or authorization.split(" ")[1] != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Invalid or missing API key"
            )
    return True

def maybe_chaos():
    if random.random() < 0.02:
        return JsonResponse(
            status_code=500,
            content={"error": "Internal Server Error (simulated chaos)", "id": str(uuid.uuid4())},
        )
    return None

def paginate(items, page, page_size):
    total = len(items)
    total_pages = (total + page_size - 1) // page_size
    start = (page - 1) * page_size
    end = start + page_size
    data = items[start:end]
    next_page = page+1 if page < total_pages else None
    return {
        "page": page,
        "page_size": page_size,
        "total_pages": total_pages,
        "next_page": next_page,
        "count": len(data),
        "data": data,
    }

@app.get("/health")
def health():
    return {"status":"ok"}

@app.get("/customers")
@app.get("/payments")
@app.get("/sessions")
def list_resources():
    if not require_auth():
        return JsonResponse({"error":"unauthorized"}), 401
    if not check_rate_limit():
        return JsonResponse({"error":"rate_limited","retry_after":30}), 429
    chaos = maybe_chaos()
    if chaos:
        return chaos

    path = request.path.strip("/")
    if path == "customers":
        items = data.customers
    elif path == "payments":
        items = data.payments
    else:
        items = data.sessions

    # filtering (minimal examples)
    qs = request.args
    updated_since = qs.get("updated_since")
    if updated_since:
        ts = parser.isoparse(updated_since)
        items = [i for i in items if parser.isoparse(i.get("updated_at") or i.get("created_at") or i.get("session_start")) >= ts]

    # example filters
    status = qs.get("status")
    if status and path == "payments":
        items = [i for i in items if i["status"] == status]
    country = qs.get("country")
    if country:
        items = [i for i in items if i.get("country") == country]

    source = qs.get("source")
    if source and path == "sessions":
        items = [i for i in items if i.get("source") == source]

    page = int(qs.get("page", 1))
    page_size = min(int(qs.get("page_size", 500)), 1000)
    return JsonResponse(paginate(items, page, page_size))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)