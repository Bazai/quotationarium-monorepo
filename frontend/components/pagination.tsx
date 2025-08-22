import React from "react";
import { cn } from "../lib/utils";
import { PageInfo } from "../lib/types";

interface PaginationProps {
  currentPage: number;
  pages: PageInfo[];
  onPageChange: (page: number) => void;
  disabled?: boolean;
  reversed?: boolean;
}

const PrevSvg = () => {
  return (
    <svg
      width="16"
      height="18"
      viewBox="0 0 16 18"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M11 16.3333L3.66663 8.99992L11 1.66659"
        stroke="currentColor"
        stroke-width="2"
      />
    </svg>
  );
};

const DoublePrevSvg = () => {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 18 18"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M8.99996 16.3333L1.66663 8.99992L8.99996 1.66659"
        stroke="currentColor"
        stroke-width="2"
      />
      <path
        d="M17 16.3333L9.66663 8.99992L17 1.66659"
        stroke="currentColor"
        stroke-width="2"
      />
    </svg>
  );
};

export default function Pagination({
  currentPage,
  pages,
  onPageChange,
  disabled = false,
  reversed = false,
}: PaginationProps) {
  const totalPages = pages.length;
  
  // When reversed, we need to work with the display order
  const displayPages = reversed ? [...pages].reverse() : pages;

  const getVisiblePages = () => {
    const result: (PageInfo | "ellipsis-start" | "ellipsis-end")[] = [];

    if (totalPages <= 4) {
      // Show all pages if 4 or fewer
      return displayPages;
    }

    // Find current page index in display order
    const currentDisplayIndex = displayPages.findIndex((p) => p.page === currentPage);

    // Determine which section we're in (based on display position)
    if (currentDisplayIndex <= 3) {
      // Beginning: show first 4 pages + ellipsis
      result.push(...displayPages.slice(0, 4));
      if (totalPages > 4) {
        result.push("ellipsis-end");
      }
    } else if (currentDisplayIndex > totalPages - 4) {
      // End: show ellipsis + last 4 pages
      result.push("ellipsis-start");
      result.push(...displayPages.slice(-4));
    } else {
      // Middle: ellipsis + 4 pages around current + ellipsis
      result.push("ellipsis-start");

      // Find 4 pages centered around current page in display order
      const start = Math.max(0, Math.min(currentDisplayIndex - 1, totalPages - 4));
      const end = Math.min(totalPages, start + 4);

      result.push(...displayPages.slice(start, end));
      result.push("ellipsis-end");
    }

    return result;
  };

  const visiblePages = getVisiblePages();
  const firstPage = displayPages[0]?.page || 1;
  const lastPage = displayPages[displayPages.length - 1]?.page || 1;

  return (
    <div className="flex flex-nowrap gap-2 items-center justify-center">
      {/* First page button */}
      <div
        className={cn(
          "page inter cursor-pointer px-3 inline-flex items-center",
          (disabled || currentPage === firstPage) &&
            "opacity-50 cursor-not-allowed"
        )}
        onClick={() =>
          !disabled && currentPage !== firstPage && onPageChange(firstPage)
        }
      >
        <DoublePrevSvg />
      </div>

      {/* Previous page button */}
      <div
        className={cn(
          "page inter cursor-pointer px-3 inline-flex items-center",
          (disabled || currentPage === firstPage) &&
            "opacity-50 cursor-not-allowed"
        )}
        onClick={() => {
          if (!disabled && currentPage !== firstPage) {
            const prevPage = reversed ? currentPage + 1 : currentPage - 1;
            onPageChange(prevPage);
          }
        }}
      >
        <PrevSvg />
      </div>

      {/* Page numbers */}
      {visiblePages.map((item, index) => {
        if (item === "ellipsis-start" || item === "ellipsis-end") {
          return (
            <div key={`ellipsis-${index}`} className="page bg-transparent">
              ...
            </div>
          );
        }

        const pageInfo = item as PageInfo;
        return (
          <div
            key={pageInfo.page}
            className={cn(
              "page inter cursor-pointer",
              pageInfo.page === currentPage && "active",
              disabled && "opacity-50 cursor-not-allowed"
            )}
            onClick={() => !disabled && onPageChange(pageInfo.page)}
          >
            {pageInfo.label}
          </div>
        );
      })}

      {/* Next page button */}
      <div
        className={cn(
          "page inter cursor-pointer px-3 inline-flex items-center",
          (disabled || currentPage === lastPage) &&
            "opacity-50 cursor-not-allowed"
        )}
        onClick={() => {
          if (!disabled && currentPage !== lastPage) {
            const nextPage = reversed ? currentPage - 1 : currentPage + 1;
            onPageChange(nextPage);
          }
        }}
      >
        <div className="rotate-180">
          <PrevSvg />
        </div>
      </div>

      {/* Last page button */}
      <div
        className={cn(
          "page inter cursor-pointer px-3 inline-flex items-center",
          (disabled || currentPage === lastPage) &&
            "opacity-50 cursor-not-allowed"
        )}
        onClick={() =>
          !disabled && currentPage !== lastPage && onPageChange(lastPage)
        }
      >
        <div className="rotate-180">
          <DoublePrevSvg />
        </div>
      </div>
    </div>
  );
}
