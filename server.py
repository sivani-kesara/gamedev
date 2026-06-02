import json
import uuid
import random
import sqlite3
import bcrypt
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager

def init_db():
    conn = sqlite3.connect("players.db")
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS users (
            username TEXT PRIMARY KEY,
            password_hash TEXT,
            avatar_data TEXT
        )
    ''')
    conn.commit()
    conn.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield

app = FastAPI(lifespan=lifespan)

players: dict = {}
connected_clients: list[tuple[str, WebSocket]] = []

async def broadcast(message: dict):
    """Send a JSON message to every connected client."""
    payload = json.dumps(message)
    disconnected = []
    for client_id, ws in connected_clients:
        try:
            await ws.send_text(payload)
        except Exception:
            disconnected.append((client_id, ws))
    for item in disconnected:
        connected_clients.remove(item)

def random_color() -> str:
    """Return a random hex color string like '0xRRGGBB'."""
    r = random.randint(40, 220)
    g = random.randint(40, 220)
    b = random.randint(40, 220)
    return f"0x{r:02x}{g:02x}{b:02x}"

def generate_default_avatar(username: str) -> dict:
    return {
        "x": 360,
        "y": 500,
        "color": random_color(),
        "name": username,
        "mood": "is happy",
        "hair": "emo_black",
        "hat": "cap_sb",
        "outfit": "collared_tie",
        "back": "skateboard",
        "aura": "grass",
        "skin": "default",
        "days": random.randint(10, 1500),
        "level": random.randint(1, 40)
    }

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()

    client_id = str(uuid.uuid4())
    connected_clients.append((client_id, websocket))

    # Send the new client the full current state of players
    await websocket.send_text(json.dumps({
        "type": "init",
        "id": client_id,
        "players": players,
    }))

    try:
        while True:
            raw = await websocket.receive_text()
            data = json.loads(raw)
            action = data.get("action")

            if action == "signup":
                username = data.get("username", "").strip()
                password = data.get("password", "")
                if not username or not password:
                    await websocket.send_text(json.dumps({"type": "auth_error", "message": "Missing fields"}))
                    continue
                
                conn = sqlite3.connect("players.db")
                c = conn.cursor()
                c.execute("SELECT username FROM users WHERE username=?", (username,))
                if c.fetchone():
                    conn.close()
                    await websocket.send_text(json.dumps({"type": "auth_error", "message": "Username taken"}))
                else:
                    hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
                    avatar_data = generate_default_avatar(username)
                    c.execute("INSERT INTO users (username, password_hash, avatar_data) VALUES (?, ?, ?)", 
                              (username, hashed, json.dumps(avatar_data)))
                    conn.commit()
                    conn.close()
                    
                    players[client_id] = avatar_data
                    await websocket.send_text(json.dumps({"type": "auth_success", "avatar_data": avatar_data}))
                    await broadcast({"type": "playerJoined", "id": client_id, "player": avatar_data})

            elif action == "login":
                username = data.get("username", "").strip()
                password = data.get("password", "")
                conn = sqlite3.connect("players.db")
                c = conn.cursor()
                c.execute("SELECT password_hash, avatar_data FROM users WHERE username=?", (username,))
                row = c.fetchone()
                conn.close()

                if not row:
                    await websocket.send_text(json.dumps({"type": "auth_error", "message": "User not found"}))
                else:
                    stored_hash = row[0].encode('utf-8')
                    if bcrypt.checkpw(password.encode('utf-8'), stored_hash):
                        avatar_data = json.loads(row[1])
                        # Ensure name is intact
                        avatar_data["name"] = username
                        avatar_data["x"] = 360
                        avatar_data["y"] = 500
                        players[client_id] = avatar_data
                        
                        await websocket.send_text(json.dumps({"type": "auth_success", "avatar_data": avatar_data}))
                        await broadcast({"type": "playerJoined", "id": client_id, "player": avatar_data})
                    else:
                        await websocket.send_text(json.dumps({"type": "auth_error", "message": "Wrong password"}))

            elif action == "move":
                if client_id in players:
                    new_x = data["x"]
                    new_y = data["y"]
                    players[client_id]["x"] = new_x
                    players[client_id]["y"] = new_y
                    await broadcast({
                        "type": "playerMoved",
                        "id": client_id,
                        "x": new_x,
                        "y": new_y,
                    })

            elif action == "chat":
                if client_id in players:
                    message = data.get("message", "")
                    await broadcast({
                        "type": "playerChat",
                        "id": client_id,
                        "message": message,
                    })

            elif action == "customize":
                if client_id in players:
                    players[client_id].update({
                        "hair": data.get("hair", players[client_id].get("hair")),
                        "hat": data.get("hat", players[client_id].get("hat")),
                        "outfit": data.get("outfit", players[client_id].get("outfit")),
                        "back": data.get("back", players[client_id].get("back")),
                        "aura": data.get("aura", players[client_id].get("aura")),
                        "mood": data.get("mood", players[client_id].get("mood")),
                        "color": data.get("color", players[client_id].get("color")),
                        "name": data.get("name", players[client_id].get("name")),
                        "skin": data.get("skin", players[client_id].get("skin")),
                    })
                    
                    # Persist changes to SQLite
                    username = players[client_id].get("name")
                    if username:
                        conn = sqlite3.connect("players.db")
                        c = conn.cursor()
                        c.execute("UPDATE users SET avatar_data=? WHERE username=?", (json.dumps(players[client_id]), username))
                        conn.commit()
                        conn.close()

                    await broadcast({
                        "type": "playerCustomized",
                        "id": client_id,
                        "player": players[client_id]
                    })

    except WebSocketDisconnect:
        pass
    except Exception as e:
        print(f"Error: {e}")
    finally:
        connected_clients[:] = [
            (cid, ws) for cid, ws in connected_clients if cid != client_id
        ]
        if client_id in players:
            players.pop(client_id, None)
            await broadcast({
                "type": "playerLeft",
                "id": client_id,
            })

# Mount static files LAST so the /ws route takes priority
app.mount("/", StaticFiles(directory="public", html=True), name="static")
