from typing import List, Optional, Tuple
from fastapi import HTTPException

from ..models.patient import Patient, Step, Image
from ..schemas.patient_schema import PatientCreate


STEP_TITLES: List[str] = [
    "صورة وجه كامل للمريض",
    "صورة ابتسامة المريض بدون وجه",
    "صورة ابتسامة مع ريتراكتد",
    "صورة ابتسامة مع ريتراكتد يمين",
    "صورة ابتسامة مع ريتراكتد يسار",
    "صورة اللهاة العلوية",
    "صورة اللهاة السفلية",
    "صورة الأشعة قبل الزراعة",
    "مكان الزراعة قبل الشق",
    "مكان الزراعة بعد الشق",
    "وضع الدرل",
    "الزرعة داخل الفم",
    "صورة الخيط",
    "الأشعة بعد الزراعة",
    "صورة الطبعة",
    "التركيب على القالب",
    "التركيب داخل الفم ابتسامة",
    "التركيب داخل الفم يمين",
    "التركيب داخل الفم يسار",
    "اللهاة العلوية",
    "اللهاة السفلية",
    "صورة وجه كامل",
    "صورة المعالجة",
]


def generate_default_steps() -> List[Step]:
    steps: List[Step] = []
    for i, title in enumerate(STEP_TITLES, start=1):
        steps.append(Step(step_number=i, title=title))
    return steps


async def create_patient(data: PatientCreate) -> Patient:
    patient = Patient(
        name=data.name,
        phone=data.phone,
        address=data.address,
        steps=generate_default_steps(),
    )
    await patient.insert()
    return patient


async def list_patients() -> List[Patient]:
    return await Patient.find_all().to_list()


async def search_patients(q: Optional[str], page: int, limit: int) -> dict:
    skip = (page - 1) * limit
    if q:
        filter_query = {
            "$or": [
                {"name": {"$regex": q, "$options": "i"}},
                {"phone": {"$regex": q, "$options": "i"}},
            ]
        }
        cursor = Patient.find(filter_query)
        total = await Patient.find(filter_query).count()
    else:
        cursor = Patient.find_all()
        total = await Patient.find_all().count()

    patients = await cursor.skip(skip).limit(limit).to_list()

    pages = (total + limit - 1) // limit if total else 0
    return {
        "data": patients,
        "pagination": {
            "total": total,
            "page": page,
            "limit": limit,
            "pages": pages,
        },
        "query": q,
    }


async def get_patient(patient_id: str) -> Patient:
    patient = await Patient.get(patient_id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    return patient


async def update_patient(patient_id: str, name: str, phone: str, address: str) -> Patient:
    """تحديث بيانات المريض الأساسية"""
    patient = await get_patient(patient_id)
    patient.name = name
    patient.phone = phone
    patient.address = address
    await patient.save()
    return patient


def get_step(patient: Patient, step_number: int) -> Step:
    for step in patient.steps:
        if step.step_number == step_number:
            return step
    raise HTTPException(status_code=404, detail="Step not found")


async def mark_step_done(patient_id: str, step_number: int, is_done: bool = True) -> Patient:
    patient = await get_patient(patient_id)
    step = get_step(patient, step_number)
    step.is_done = is_done
    await patient.save()
    return patient


async def add_images_to_step(patient_id: str, step_number: int, images: List[Image]) -> Patient:
    patient = await get_patient(patient_id)
    step = get_step(patient, step_number)
    step.images.extend(images)
    await patient.save()
    return patient


async def delete_image_from_step(patient_id: str, step_number: int, image_id: str) -> Patient:
    patient = await get_patient(patient_id)
    step = get_step(patient, step_number)
    before = len(step.images)
    step.images = [img for img in step.images if img.id != image_id]
    if len(step.images) == before:
        raise HTTPException(status_code=404, detail="Image not found")
    await patient.save()
    return patient


async def get_statistics() -> dict:
    """جلب إحصائيات المرضى"""
    all_patients = await Patient.find_all().to_list()
    total = len(all_patients)
    
    completed = 0
    incomplete = 0
    
    for patient in all_patients:
        all_steps_done = all(step.is_done for step in patient.steps)
        if all_steps_done:
            completed += 1
        else:
            incomplete += 1
    
    return {
        "total_patients": total,
        "completed_patients": completed,
        "incomplete_patients": incomplete,
    }


async def get_completed_patients() -> List[Patient]:
    """جلب فقط المرضى المكتملين"""
    all_patients = await Patient.find_all().to_list()
    completed_patients = []
    
    for patient in all_patients:
        if all(step.is_done for step in patient.steps):
            completed_patients.append(patient)
    
    return completed_patients


async def delete_patient(patient_id: str) -> None:
    """حذف مريض"""
    patient = await get_patient(patient_id)
    await patient.delete()
