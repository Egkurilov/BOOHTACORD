"""Inventory native payload without extracting APK content."""
import zipfile

DOWNLOAD_BUDGETS = {'armeabi-v7a': 25000000, 'arm64-v8a': 30000000, 'x86_64': 35000000}


def inspect_size(apk, *, release, architecture):
    size = apk.stat().st_size
    if release and (architecture not in DOWNLOAD_BUDGETS or size > DOWNLOAD_BUDGETS[architecture]):
        raise ValueError('APK exceeds its architecture download budget')
    with zipfile.ZipFile(apk) as archive:
        entries = archive.infolist()
        if release and any(entry.filename.endswith('/kernel_blob.bin') for entry in entries):
            raise ValueError('Flutter debug kernel cannot be published as release')
        native = [entry for entry in archive.infolist()
                  if entry.filename.startswith('lib/') and entry.filename.endswith('.so')]
        arches = sorted({entry.filename.split('/')[1] for entry in native})
        if release and arches != [architecture]:
            raise ValueError('Release APK must contain exactly its declared architecture')
        if release and any(entry.compress_type != zipfile.ZIP_DEFLATED for entry in native):
            raise ValueError('Release native libraries must be compressed')
        return {'apk_bytes': size, 'architectures': arches,
                'native_bytes': sum(entry.file_size for entry in native),
                'native_compressed_bytes': sum(entry.compress_size for entry in native)}
