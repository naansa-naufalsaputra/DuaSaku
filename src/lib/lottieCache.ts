import * as FileSystem from 'expo-file-system';
import { Paths } from 'expo-file-system/next';

const LOTTIE_CACHE_DIR = `${Paths.cache.uri}/lottie_cache/`;

/**
 * Ensures the cache directory exists.
 */
async function ensureDirExists() {
  const dirInfo = await FileSystem.getInfoAsync(LOTTIE_CACHE_DIR);
  if (!dirInfo.exists) {
    await FileSystem.makeDirectoryAsync(LOTTIE_CACHE_DIR, { intermediates: true });
  }
}

/**
 * Gets a local URI for a Lottie JSON.
 * Downloads it if not already cached.
 */
export async function getCachedLottie(url: string): Promise<string> {
  await ensureDirExists();
  
  // Create a filename from the URL
  const filename = url.split('/').pop() || 'animation.json';
  const fileUri = `${LOTTIE_CACHE_DIR}${filename}`;
  
  const fileInfo = await FileSystem.getInfoAsync(fileUri);
  
  if (fileInfo.exists) {
    return fileUri;
  }

  try {
    console.log(`[LottieCache] Downloading: ${url}`);
    const { uri } = await FileSystem.downloadAsync(url, fileUri);
    return uri;
  } catch (error) {
    console.error(`[LottieCache] Failed to download ${url}:`, error);
    return url; // Fallback to remote URL if download fails
  }
}

/**
 * Clears all cached Lottie animations.
 */
export async function clearLottieCache() {
  const dirInfo = await FileSystem.getInfoAsync(LOTTIE_CACHE_DIR);
  if (dirInfo.exists) {
    await FileSystem.deleteAsync(LOTTIE_CACHE_DIR, { idempotent: true });
  }
}
