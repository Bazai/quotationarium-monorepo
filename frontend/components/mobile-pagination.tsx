import React from "react";
import { cn } from "../lib/utils";
import { PageInfo } from "../lib/types";

interface MobilePaginationProps {
  currentPage: number;
  pages: PageInfo[];
  onPageChange: (page: number) => void;
  disabled?: boolean;
  reversed?: boolean;
}

const PrevSvg = () => {
  return (
    <svg
      width="24"
      height="24"
      viewBox="0 0 16 18"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M11 16.3333L3.66663 8.99992L11 1.66659"
        stroke="currentColor"
        strokeWidth="2"
      />
    </svg>
  );
};

const DoublePrevSvg = () => {
  return (
    <svg
      width="24"
      height="24"
      viewBox="0 0 18 18"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M8.99996 16.3333L1.66663 8.99992L8.99996 1.66659"
        stroke="currentColor"
        strokeWidth="2"
      />
      <path
        d="M17 16.3333L9.66663 8.99992L17 1.66659"
        stroke="currentColor"
        strokeWidth="2"
      />
    </svg>
  );
};

export default function MobilePagination({
  currentPage,
  pages,
  onPageChange,
  disabled = false,
  reversed = false,
}: MobilePaginationProps) {
  // When reversed, we need to work with the display order
  const displayPages = reversed ? [...pages].reverse() : pages;
  const firstPage = displayPages[0]?.page || 1;
  const lastPage = displayPages[displayPages.length - 1]?.page || 1;
  const currentPageInfo = pages.find((p) => p.page === currentPage);

  return (
    <div className="ml-auto flex gap-2 items-center">
      {/* First page button */}
      <button
        onClick={() =>
          !disabled && currentPage !== firstPage && onPageChange(firstPage)
        }
        disabled={disabled || currentPage === firstPage}
        className={cn(
          "page inter cursor-pointer px-3 inline-flex items-center",
          (disabled || currentPage === firstPage) &&
            "opacity-50 cursor-not-allowed"
        )}
      >
        <DoublePrevSvg />
      </button>

      {/* Previous page button */}
      <button
        onClick={() => {
          if (!disabled && currentPage !== firstPage) {
            const prevPage = reversed ? currentPage + 1 : currentPage - 1;
            onPageChange(prevPage);
          }
        }}
        disabled={disabled || currentPage === firstPage}
        className={cn(
          "page inter cursor-pointer px-3 inline-flex items-center",
          (disabled || currentPage === firstPage) &&
            "opacity-50 cursor-not-allowed"
        )}
      >
        <PrevSvg />
      </button>

      {/* Current page display */}
      {currentPageInfo && (
        <div className="page inter px-4 w-fit cursor-default">
          {currentPageInfo.label}
        </div>
      )}

      {/* Next page button */}
      <button
        onClick={() => {
          if (!disabled && currentPage !== lastPage) {
            const nextPage = reversed ? currentPage - 1 : currentPage + 1;
            onPageChange(nextPage);
          }
        }}
        disabled={disabled || currentPage === lastPage}
        className={cn(
          "page inter cursor-pointer px-3 inline-flex items-center",
          (disabled || currentPage === lastPage) &&
            "opacity-50 cursor-not-allowed"
        )}
      >
        <div className="rotate-180">
          <PrevSvg />
        </div>
      </button>

      {/* Last page button */}
      <button
        onClick={() =>
          !disabled && currentPage !== lastPage && onPageChange(lastPage)
        }
        disabled={disabled || currentPage === lastPage}
        className={cn(
          "page inter cursor-pointer px-3 inline-flex items-center",
          (disabled || currentPage === lastPage) &&
            "opacity-50 cursor-not-allowed"
        )}
      >
        <div className="rotate-180">
          <DoublePrevSvg />
        </div>
      </button>
    </div>
  );
}
