const { createHash } = require('node:crypto');
const sharp = require('sharp');

const MAX_BYTES = 2 * 1024 * 1024;
const MAX_DIMENSION = 1600;
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');

class PhotoError extends Error {
  constructor(code, status = 422) { super(code); this.code = code; this.status = status; }
}

async function sanitizePhoto(bytes) {
  if (!Buffer.isBuffer(bytes) || !bytes.length || bytes.length > MAX_BYTES
    || bytes[0] !== 0xff || bytes[1] !== 0xd8) throw new PhotoError('invalid_photo');
  try {
    const input = sharp(bytes, { limitInputPixels: MAX_DIMENSION ** 2, failOn: 'warning' });
    const meta = await input.metadata();
    if (meta.format !== 'jpeg' || !meta.width || !meta.height
      || meta.width > MAX_DIMENSION || meta.height > MAX_DIMENSION
      || (meta.pages ?? 1) !== 1) throw new PhotoError('invalid_photo');
    // No withMetadata/keepMetadata: the output is a fresh raster and JPEG.
    for (const quality of [85, 70, 55, 40]) {
      const { data, info } = await input.clone().rotate().toColourspace('srgb')
        .removeAlpha().jpeg({ quality, chromaSubsampling: '4:2:0' })
        .toBuffer({ resolveWithObject: true });
      if (data.length <= MAX_BYTES) return {
        bytes: data, width: info.width, height: info.height,
        sha256: digest(data), byteLength: data.length,
      };
    }
    throw new PhotoError('invalid_photo');
  } catch (error) {
    if (error instanceof PhotoError) throw error;
    // Decoder diagnostics may contain source metadata; never forward them.
    throw new PhotoError('invalid_photo');
  }
}
module.exports = { sanitizePhoto, digest, PhotoError, MAX_BYTES };
