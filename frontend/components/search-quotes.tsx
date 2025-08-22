import React from "react";
import QuotesList from "./quotes-list";
import { useQuotesSearch } from "../hooks/useQuotesSearch";
import { useQuotesPagination } from "../hooks/useQuotesPagination";

interface SearchQuotesProps {
  search: string;
  type?: string | null;
  topic?: string | null;
}

const SearchQuotes: React.FC<SearchQuotesProps> = ({ search, type, topic }) => {
  // Use search hook to get quotes
  const {
    quotes: allQuotes,
    loading,
    error,
    hasSearched,
  } = useQuotesSearch({
    searchTerm: search,
    type,
    topic,
  });

  // Use pagination hook for client-side pagination
  const {
    currentData: paginatedQuotes,
    currentPage,
    totalPages,
    canGoNext,
    canGoPrevious,
    goNext,
    goPrevious,
    pageLabels,
  } = useQuotesPagination({
    type: "client",
    data: allQuotes,
    itemsPerPage: 100,
  });

  // Don't render anything if no search has been performed
  if (!hasSearched && !loading) {
    return null;
  }

  // Show pagination controls if there are multiple pages
  const showPagination = totalPages > 1 && allQuotes.length > 0;

  return (
    <div className="sm:mb-0">
      <QuotesList
        quotes={paginatedQuotes}
        loading={loading}
        error={error}
        showNumbers={true}
        bottomPagination={
          showPagination ? (
            <div className="flex justify-center items-center gap-4 mt-4 py-4">
              <button
                onClick={goPrevious}
                disabled={!canGoPrevious}
                className={`px-4 py-2 rounded ${
                  canGoPrevious
                    ? "bg-blue-500 text-white hover:bg-blue-600"
                    : "bg-gray-300 text-gray-500 cursor-not-allowed"
                }`}
              >
                Previous
              </button>

              <span className="text-sm text-gray-600">
                Page {currentPage} of {totalPages}
                {pageLabels[currentPage - 1] && (
                  <span className="ml-2 text-xs">
                    ({pageLabels[currentPage - 1]})
                  </span>
                )}
              </span>

              <button
                onClick={goNext}
                disabled={!canGoNext}
                className={`px-4 py-2 rounded ${
                  canGoNext
                    ? "bg-blue-500 text-white hover:bg-blue-600"
                    : "bg-gray-300 text-gray-500 cursor-not-allowed"
                }`}
              >
                Next
              </button>
            </div>
          ) : undefined
        }
      />
    </div>
  );
};

SearchQuotes.displayName = "SearchQuotes";

export default SearchQuotes;
