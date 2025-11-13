from fastapi import APIRouter, status, Depends, Query, HTTPException
from typing import Optional

from ..schemas.patient_schema import PatientCreate
from ..services import patient_service
from ..utils.security import get_current_user
from ..models.user import Photographer

router = APIRouter(dependencies=[Depends(get_current_user)])


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_patient(payload: PatientCreate):
    patient = await patient_service.create_patient(payload)
    return {"success": True, "data": patient}


@router.get("")
async def list_patients(q: Optional[str] = Query(default=None), page: int = Query(1, ge=1), limit: int = Query(20, ge=1, le=100)):
    result = await patient_service.search_patients(q=q, page=page, limit=limit)
    return {"success": True, **result}


# هذه الـ routes لازم تكون قبل /{patient_id}
@router.get("/stats/dashboard")
async def get_stats(current_user: Photographer = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    stats = await patient_service.get_statistics()
    return {"success": True, "data": stats}


@router.get("/filter/completed")
async def get_completed_patients(current_user: Photographer = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    patients = await patient_service.get_completed_patients()
    return {"success": True, "data": patients}


@router.get("/{patient_id}")
async def get_patient(patient_id: str):
    patient = await patient_service.get_patient(patient_id)
    return {"success": True, "data": patient}


@router.delete("/{patient_id}")
async def delete_patient(patient_id: str, current_user: Photographer = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    await patient_service.delete_patient(patient_id)
    return {"success": True, "message": "Patient deleted successfully"}
