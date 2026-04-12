"""
OCR Abstract Layer — ADL ShareFlow

Providers:
  - GoogleVisionProvider  (default, production)
  - MockProvider          (testing / dev without credentials)
"""
import re
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Optional


@dataclass
class OCRResult:
    raw_text: str
    extracted_amount: Optional[Decimal]
    extracted_merchant: Optional[str]
    extracted_date: Optional[date]
    confidence: float  # 0.0 - 1.0


class OCRProvider(ABC):
    @abstractmethod
    def scan(self, image_bytes: bytes) -> OCRResult:
        """Scan image bytes and return extracted data."""


class GoogleVisionProvider(OCRProvider):
    def scan(self, image_bytes: bytes) -> OCRResult:
        from google.cloud import vision

        client = vision.ImageAnnotatorClient()
        image = vision.Image(content=image_bytes)
        response = client.document_text_detection(image=image)

        if response.error.message:
            raise RuntimeError(f'Google Vision error: {response.error.message}')

        raw_text = response.full_text_annotation.text or ''
        amount = _extract_amount(raw_text)
        merchant = _extract_merchant(raw_text)
        receipt_date = _extract_date(raw_text)

        return OCRResult(
            raw_text=raw_text,
            extracted_amount=amount,
            extracted_merchant=merchant,
            extracted_date=receipt_date,
            confidence=0.9 if amount else 0.5,
        )


class MockProvider(OCRProvider):
    """Returns fake data for dev/testing without Google credentials."""
    def scan(self, image_bytes: bytes) -> OCRResult:
        return OCRResult(
            raw_text='MOCK RECEIPT\nSupermarket ABC\nTotal: 125.50 ILS\nDate: 2025-01-15',
            extracted_amount=Decimal('125.50'),
            extracted_merchant='Supermarket ABC',
            extracted_date=date(2025, 1, 15),
            confidence=1.0,
        )


def get_ocr_provider() -> OCRProvider:
    import os
    if os.getenv('GOOGLE_APPLICATION_CREDENTIALS'):
        return GoogleVisionProvider()
    return MockProvider()


# ---------------------------------------------------------------------------
# Text parsers
# ---------------------------------------------------------------------------

def _extract_amount(text: str) -> Optional[Decimal]:
    """Extract the largest monetary amount found in the text."""
    patterns = [
        r'(?:total|סה"כ|סהכ|לתשלום|amount|sum)[^\d]{0,10}([\d,]+\.?\d{0,2})',
        r'([\d,]+\.\d{2})\s*(?:₪|ILS|USD|\$|€|EUR)',
        r'(?:₪|\$|€)\s*([\d,]+\.?\d{0,2})',
    ]
    candidates = []
    for pattern in patterns:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            val = match.group(1).replace(',', '')
            try:
                candidates.append(Decimal(val))
            except Exception:
                pass

    return max(candidates) if candidates else None


def _extract_merchant(text: str) -> Optional[str]:
    """Return the first non-empty line as merchant name (heuristic)."""
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    for line in lines[:5]:
        if len(line) > 2 and not re.match(r'^[\d\s\.,\-]+$', line):
            return line[:100]
    return None


def _extract_date(text: str) -> Optional[date]:
    """Extract a date from common formats."""
    patterns = [
        r'(\d{4}[-/]\d{2}[-/]\d{2})',   # 2025-01-15
        r'(\d{2}[-/]\d{2}[-/]\d{4})',   # 15/01/2025
        r'(\d{2}[-/]\d{2}[-/]\d{2})',   # 15/01/25
    ]
    for pattern in patterns:
        m = re.search(pattern, text)
        if m:
            raw = m.group(1).replace('/', '-')
            parts = raw.split('-')
            try:
                if len(parts[0]) == 4:
                    return date(int(parts[0]), int(parts[1]), int(parts[2]))
                else:
                    year = int(parts[2])
                    if year < 100:
                        year += 2000
                    return date(year, int(parts[1]), int(parts[0]))
            except Exception:
                continue
    return None
