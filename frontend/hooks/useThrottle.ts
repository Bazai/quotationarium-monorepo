import { useState, useEffect, useRef, useCallback } from "react";

/**
 * Custom hook to throttle a value
 * Unlike debounce, throttle ensures the value updates at regular intervals
 * during continuous changes, providing better UX for drag operations
 */
export function useThrottle<T>(value: T, delay: number): T {
  const [throttledValue, setThrottledValue] = useState<T>(value);
  const lastExecuted = useRef<number>(0);
  const timeoutId = useRef<NodeJS.Timeout | null>(null);
  const pendingValue = useRef<T>(value);

  const updateValue = useCallback((newValue: T) => {
    setThrottledValue(newValue);
    lastExecuted.current = Date.now();
  }, []);

  useEffect(() => {
    pendingValue.current = value;
    const now = Date.now();
    const timeSinceLastExecution = now - lastExecuted.current;

    // Don't throttle if it's the same value
    if (throttledValue === value) {
      return;
    }

    // If enough time has passed, update immediately
    if (timeSinceLastExecution >= delay) {
      updateValue(value);
    } else {
      // Clear any pending timeout
      if (timeoutId.current) {
        clearTimeout(timeoutId.current);
        timeoutId.current = null;
      }

      const remainingTime = delay - timeSinceLastExecution;
      // Schedule an update for the remaining time
      timeoutId.current = setTimeout(() => {
        updateValue(pendingValue.current);
        timeoutId.current = null;
      }, remainingTime);
    }

    // Cleanup function
    return () => {
      if (timeoutId.current) {
        clearTimeout(timeoutId.current);
        timeoutId.current = null;
      }
    };
  }, [value, delay, throttledValue, updateValue]);

  return throttledValue;
}
