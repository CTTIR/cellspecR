"""Create synthetic NumPy boundary fixtures; requires NumPy."""
from pathlib import Path
import io
import zipfile
import numpy as np

output = Path(__file__).resolve().parents[2] / "tests/testthat/fixtures/numpy"
output.mkdir(exist_ok=True)
values = {
    "i4": [-2**31, -1, 0, 2**31-1],
    "u4": [0, 2**31, 2**32-1],
    "i8": [-2**53, -2**53+1, -2**31, 2**31, 2**53-1, 2**53],
    "u8": [0, 2**31, 2**32, 2**53],
}
for dtype, numbers in values.items():
    for endian, label in [("<", "le"), (">", "be")]:
        np.save(output / f"{dtype}-{label}.npy",
                np.array(numbers, dtype=endian+dtype), allow_pickle=False)
member = io.BytesIO()
np.save(member, np.array([1, 2], dtype="<i8"), allow_pickle=False)
with zipfile.ZipFile(output / "duplicate.npz", "w") as archive:
    archive.writestr("x.npy", member.getvalue())
    archive.writestr("x.npy", member.getvalue())
