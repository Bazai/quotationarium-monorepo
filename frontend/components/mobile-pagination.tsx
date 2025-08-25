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

// Локальный компонент кнопки пагинации
interface PaginationButtonProps {
  onClick: () => void;
  disabled: boolean;
  children: React.ReactNode;
  className?: string;
}

const PaginationButton: React.FC<PaginationButtonProps> = ({
  onClick,
  disabled,
  children,
  className = "",
}) => (
  <button
    onClick={onClick}
    disabled={disabled}
    className={cn(
      "bg-secondary text-primary rounded-2xl h-10 text-center leading-10 cursor-default whitespace-nowrap font-medium font-inter",
      "flex items-center justify-center",
      "w-full h-full",
      disabled && "opacity-50 cursor-not-allowed",
      className
    )}
  >
    {children}
  </button>
);

// Компонент для отображения текущей страницы
const PageDisplay: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div className="bg-secondary text-primary rounded-2xl h-10 px-4 text-center leading-10 cursor-default whitespace-nowrap font-medium font-inter w-fit">
    {children}
  </div>
);

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
    <div
      className="ml-auto grid gap-2 items-center text-sm"
      style={{
        gridTemplateColumns:
          "minmax(40px, 56px) minmax(40px, 56px) auto minmax(40px, 56px) minmax(40px, 56px)",
      }}
    >
      {/* First page button */}
      <PaginationButton
        onClick={() =>
          !disabled && currentPage !== firstPage && onPageChange(firstPage)
        }
        disabled={disabled || currentPage === firstPage}
      >
        <DoublePrevSvg />
      </PaginationButton>

      {/* Previous page button */}
      <PaginationButton
        onClick={() => {
          if (!disabled && currentPage !== firstPage) {
            const prevPage = reversed ? currentPage + 1 : currentPage - 1;
            onPageChange(prevPage);
          }
        }}
        disabled={disabled || currentPage === firstPage}
      >
        <PrevSvg />
      </PaginationButton>

      {/* Current page display */}
      {currentPageInfo && <PageDisplay>{currentPageInfo.label}</PageDisplay>}

      {/* Next page button */}
      <PaginationButton
        onClick={() => {
          if (!disabled && currentPage !== lastPage) {
            const nextPage = reversed ? currentPage - 1 : currentPage + 1;
            onPageChange(nextPage);
          }
        }}
        disabled={disabled || currentPage === lastPage}
      >
        <div className="rotate-180">
          <PrevSvg />
        </div>
      </PaginationButton>

      {/* Last page button */}
      <PaginationButton
        onClick={() =>
          !disabled && currentPage !== lastPage && onPageChange(lastPage)
        }
        disabled={disabled || currentPage === lastPage}
      >
        <div className="rotate-180">
          <DoublePrevSvg />
        </div>
      </PaginationButton>
    </div>
  );
}
