from pydantic import BaseModel
from typing import Optional


class PatientCreate(BaseModel):
    name: str
    phone: str
    address: str


class PatientUpdate(BaseModel):
    name: str
    phone: str
    address: str


class StepDoneRequest(BaseModel):
    is_done: Optional[bool] = True
