import os, time, random, uuid, threading
import uvicorn
from fastapi import FastAPI, HTTPException, status, Request
from fastapi.responses import JSONResponse
from dateutil import parser
from generator import DataGenerator

API_KEY = os.environ.get("API_KEY", "default_key")
RATE = int(os.environ.get("API_RATE_LIMIT_PER_MIN", "60"))  # requests per minute
WINDOW = 60  # seconds

app = FastAPI()
data = DataGenerator()

# threading lock for rate limiting
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

def maybe_chaos():
    if random.random() < 0.02:
        return JSONResponse(
            status_code=500,
            content={"error": "Internal Server Error (simulated chaos)", "id": str(uuid.uuid4())},
        )
    return None

def paginate(items, page, page_size):
    total = len(items)
    total_pages = (total + page_size - 1) // page_size
    start = (page - 1) * page_size
    end = start + page_size
    paginated_data = items[start:end]
    next_page = page + 1 if page < total_pages else None
    return {
        "page": page,
        "page_size": page_size,
        "total_pages": total_pages,
        "next_page": next_page,
        "count": len(paginated_data),
        "data": paginated_data,
    }

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/customers")
@app.get("/payments")
@app.get("/sessions")
def list_resources(request: Request): # Chuyển request thành tham số của hàm
    # Kiểm tra Authentication thủ công
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer ") or auth_header.split(" ")[1] != API_KEY:
        return JSONResponse(content={"error": "unauthorized"}, status_code=401)
        
    if not check_rate_limit():
        return JSONResponse(content={"error": "rate_limited", "retry_after": 30}, status_code=429)
        
    chaos = maybe_chaos()
    if chaos:
        return chaos

    path = request.url.path.strip("/")
    if path == "customers":
        items = data.customers
    elif path == "payments":
        items = data.payments
    else:
        items = data.sessions

    qs = request.query_params
    
    updated_since = qs.get("updated_since")
    if updated_since:
        ts = parser.isoparse(updated_since)
        items = [i for i in items if parser.isoparse(i.get("updated_at") or i.get("created_at") or i.get("session_start")) >= ts]

    req_status = qs.get("status")
    if req_status and path == "payments":
        items = [i for i in items if i.get("status") == req_status]
        
    country = qs.get("country")
    if country:
        items = [i for i in items if i.get("country") == country]

    source = qs.get("source")
    if source and path == "sessions":
        items = [i for i in items if i.get("source") == source]

    page = int(qs.get("page", 1))
    page_size = min(int(qs.get("page_size", 500)), 1000)
    
    return JSONResponse(content=paginate(items, page, page_size))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)