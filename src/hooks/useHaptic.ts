import { HapticService } from '../lib/hapticService';

export const useHaptic = () => {
  return {
    hapticLight: HapticService.light,
    hapticMedium: HapticService.medium,
    hapticHeavy: HapticService.heavy,
    hapticSuccess: HapticService.success,
    hapticError: HapticService.error,
    hapticWarning: HapticService.warning,
    hapticTransaction: HapticService.transactionSuccess,
  };
};
