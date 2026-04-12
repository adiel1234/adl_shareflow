import random
import string
import hashlib
from decimal import Decimal


def generate_invite_code(length=10):
    """Generates a random alphanumeric invite code."""
    chars = string.ascii_uppercase + string.digits
    return ''.join(random.choices(chars, k=length))


def hash_token(token: str) -> str:
    """SHA-256 hash for storing refresh tokens securely."""
    return hashlib.sha256(token.encode()).hexdigest()


def to_decimal(value) -> Decimal:
    """Safe conversion to Decimal."""
    if value is None:
        return Decimal('0')
    return Decimal(str(value))


def paginate_query(query, page: int, per_page: int = 20):
    """Returns paginated results and total count."""
    total = query.count()
    items = query.offset((page - 1) * per_page).limit(per_page).all()
    return items, total


def allowed_image(filename: str) -> bool:
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in {'png', 'jpg', 'jpeg', 'webp', 'heic'}
