from datetime import datetime, timedelta
from typing import Optional

from jose import jwt, JWTError


def create_access_token(subject: str, secret: str, expires_delta: Optional[timedelta] = None) -> str:
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=60))
    payload = {"sub": subject, "exp": expire}
    return jwt.encode(payload, secret, algorithm="HS256")


def decode_token(token: str, secret: str) -> Optional[str]:
    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"])
        return payload.get("sub")
    except JWTError:
        return None
