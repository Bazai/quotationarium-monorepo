import React, { useRef, useState, useEffect, useCallback } from "react";
import { cn } from "../lib/utils";
import { SliderProps } from "../lib/types";
import { Icon } from "./icon";

const Slider: React.FC<SliderProps> = ({
  totalCount,
  currentPosition,
  onPositionChange,
  disabled = false,
}) => {
  const [isDragging, setIsDragging] = useState(false);
  const [visualProgress, setVisualProgress] = useState(0);
  const barRef = useRef<HTMLDivElement>(null);

  // Determine if slider should be disabled
  const isDisabled = totalCount <= 1 || disabled;

  const shouldShowTooltip = isDragging || totalCount <= 1;

  // Calculate progress from position
  const calculateProgress = useCallback(
    (position: number): number => {
      if (totalCount <= 1) return 100; // Center position for single item
      return ((position - 1) / (totalCount - 1)) * 100;
    },
    [totalCount]
  );

  // Snap to nearest position
  const snapToPosition = useCallback(
    (progress: number): number => {
      if (totalCount <= 1) return 1;

      const step = 100 / (totalCount - 1);
      const targetPosition = Math.round(progress / step) + 1;
      return Math.max(1, Math.min(totalCount, targetPosition));
    },
    [totalCount]
  );

  // Update visual progress when position changes
  useEffect(() => {
    const progress = calculateProgress(currentPosition);
    setVisualProgress(progress);
  }, [currentPosition, calculateProgress]);

  // Handle decrease (left arrow)
  const handleDecrease = useCallback(() => {
    if (isDisabled || currentPosition <= 1) return;
    onPositionChange(currentPosition - 1);
  }, [currentPosition, isDisabled, onPositionChange]);

  // Handle increase (right arrow)
  const handleIncrease = useCallback(() => {
    if (isDisabled || currentPosition >= totalCount) return;
    onPositionChange(currentPosition + 1);
  }, [currentPosition, totalCount, isDisabled, onPositionChange]);

  // Handle mouse/touch down
  const handleMouseDown = useCallback(
    (e: React.MouseEvent | React.TouchEvent) => {
      if (isDisabled) return;
      e.preventDefault();
      setIsDragging(true);
    },
    [isDisabled]
  );

  // Handle mouse move
  const handleMouseMove = useCallback(
    (e: MouseEvent | TouchEvent) => {
      if (!isDragging || !barRef.current || isDisabled) return;

      const barRect = barRef.current.getBoundingClientRect();
      const clientX = "touches" in e ? e.touches[0].clientX : e.clientX;

      const rawProgress = ((clientX - barRect.left) / barRect.width) * 100;
      const clampedProgress = Math.min(100, Math.max(0, rawProgress));

      // Update visual progress smoothly
      setVisualProgress(clampedProgress);

      // Snap to position
      const newPosition = snapToPosition(clampedProgress);
      if (newPosition !== currentPosition) {
        onPositionChange(newPosition);
      }
    },
    [isDragging, isDisabled, currentPosition, snapToPosition, onPositionChange]
  );

  // Handle mouse up
  const handleMouseUp = useCallback(() => {
    if (!isDragging) return;

    setIsDragging(false);
    // Snap visual progress to actual position
    const finalProgress = calculateProgress(currentPosition);
    setVisualProgress(finalProgress);
  }, [isDragging, currentPosition, calculateProgress]);

  // Handle click on progress bar
  const handleBarClick = useCallback(
    (e: React.MouseEvent) => {
      if (isDisabled || !barRef.current) return;

      const barRect = barRef.current.getBoundingClientRect();
      const clickProgress = ((e.clientX - barRect.left) / barRect.width) * 100;
      const newPosition = snapToPosition(clickProgress);

      if (newPosition !== currentPosition) {
        onPositionChange(newPosition);
      }
    },
    [isDisabled, currentPosition, snapToPosition, onPositionChange]
  );

  // Setup global mouse/touch listeners
  useEffect(() => {
    if (isDragging) {
      const handleGlobalMove = (e: MouseEvent | TouchEvent) =>
        handleMouseMove(e);
      const handleGlobalUp = () => handleMouseUp();

      document.addEventListener("mousemove", handleGlobalMove);
      document.addEventListener("mouseup", handleGlobalUp);
      document.addEventListener("touchmove", handleGlobalMove);
      document.addEventListener("touchend", handleGlobalUp);

      return () => {
        document.removeEventListener("mousemove", handleGlobalMove);
        document.removeEventListener("mouseup", handleGlobalUp);
        document.removeEventListener("touchmove", handleGlobalMove);
        document.removeEventListener("touchend", handleGlobalUp);
      };
    }
  }, [isDragging, handleMouseMove, handleMouseUp]);

  // Render position indicators for small counts
  const renderPositionIndicators = () => {
    if (totalCount > 10 || totalCount <= 1) return null;

    const indicators = [];
    for (let i = 1; i <= totalCount; i++) {
      const position = calculateProgress(i);
      indicators.push(
        <div
          key={i}
          className={cn(
            "absolute w-2 h-2 rounded-full bg-gray-400 -translate-x-1/2",
            i === currentPosition && "bg-primary w-3 h-3"
          )}
          style={{
            left: `${position}%`,
            top: "50%",
            transform: "translate(-50%, -50%)",
          }}
        />
      );
    }
    return indicators;
  };

  return (
    <div
      data-tid="pagination-slider"
      className={cn(
        "gap-2 fixed left-0 bottom-0 w-full h-20 p-0",
        "bg-background flex sm:hidden",
        isDisabled && "opacity-50"
      )}
    >
      <div
        className={cn(
          "container flex flex-row px-0",
          "border-t border-secondary"
        )}
      >
        <div className="basis-[80px] flex shrink-0 items-center justify-center">
          <button
            onClick={handleDecrease}
            disabled={isDisabled || currentPosition <= 1}
            className={cn(
              (isDisabled || currentPosition <= 1) &&
                "opacity-30 cursor-not-allowed"
            )}
            aria-label="Previous"
          >
            <Icon name="arrowLeft" size={24} />
          </button>
        </div>

        <div className="w-full relative">
          <div
            className={cn(
              "w-full h-full items-center flex relative",
              !isDisabled && "cursor-pointer"
            )}
            ref={barRef}
            onClick={handleBarClick}
            onMouseDown={handleMouseDown}
            onTouchStart={handleMouseDown}
            role="slider"
            aria-valuemin={1}
            aria-valuemax={totalCount}
            aria-valuenow={currentPosition}
            aria-disabled={isDisabled}
          >
            <div
              className={cn(
                "h-[3px] w-0 bg-secondary-background my-[39px] relative",
                isDragging
                  ? "transition-none"
                  : "transition-all duration-[10ms] ease-in-out"
              )}
              style={{ width: `${visualProgress}%` }}
            >
              {/* Thumb indicator */}
              <div
                className={cn(
                  "absolute w-6 h-6 bg-background rounded-[9px]",
                  "border-[3px] border-secondary-background z-[99] cursor-pointer",
                  isDragging && "scale-125",
                  "transition-transform"
                )}
                style={{
                  right: "-20px",
                  top: "-11px",
                  marginRight: "-7.5px",
                  transform: `translateX(-50%) ${
                    isDragging ? "scale(1.25)" : "scale(1)"
                  }`,
                }}
              />
            </div>

            {/* Position indicators for small counts */}
            {renderPositionIndicators()}
          </div>

          {/* Position label on hover/drag */}
          {shouldShowTooltip && (
            <div
              className="absolute -top-8 text-white text-xs px-2 py-1 text-nowrap"
              style={{
                left: `${visualProgress}%`,
                transform: "translateX(-50%)",
              }}
            >
              {currentPosition} / {totalCount}
            </div>
          )}
        </div>

        <div className="basis-[80px] flex shrink-0 items-center justify-center">
          <button
            onClick={handleIncrease}
            disabled={isDisabled || currentPosition >= totalCount}
            className={cn(
              (isDisabled || currentPosition >= totalCount) &&
                "opacity-30 cursor-not-allowed"
            )}
            aria-label="Next"
          >
            <Icon name="arrowRight" size={24} />
          </button>
        </div>
      </div>
    </div>
  );
};

Slider.displayName = "Slider";

export default Slider;
