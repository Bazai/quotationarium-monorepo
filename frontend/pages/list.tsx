import React, { useState, useEffect, useMemo, useRef } from "react";
import Head from "next/head";
import { useDebounce } from "@uidotdev/usehooks";
import { useQueryState } from "nuqs";
import Filter from "../components/filter";
import QuotesList from "../components/quotes-list";
import Pagination from "../components/pagination";
import MobilePagination from "../components/mobile-pagination";
import { cn } from "../lib/utils";
import { Quote as QuoteType, PagesInfoResponse } from "../lib/types";
import { getQuotesPage, getPagesInfo } from "../lib/quotes";

export default function List() {
  const [page, setPage] = useQueryState("page", {
    defaultValue: "1",
    parse: (value) => value || "1",
    serialize: (value) => value,
  });
  const [type, setType] = useQueryState("type", {
    defaultValue: null,
    parse: (value) => value || null,
    serialize: (value) => value || "",
  });
  const [topic, setTopic] = useQueryState("topic", {
    defaultValue: null,
    parse: (value) => value || null,
    serialize: (value) => value || "",
  });
  const [search, setSearch] = useState("");

  const [quotes, setQuotes] = useState<QuoteType[]>([]);
  const [pagesInfo, setPagesInfo] = useState<PagesInfoResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Refs to track previous values for detecting actual changes
  const prevFiltersRef = useRef<{ type: string | null; topic: string | null; search: string }>({
    type: null,
    topic: null,
    search: "",
  });
  const isInitializedRef = useRef(false);

  const debouncedSearchTerm = useDebounce(search, 300);
  const currentPage = parseInt(page) || 1;

  // Build search parameters
  const searchParams = useMemo(() => {
    const params: {
      type?: string;
      topic?: string;
      search?: string;
      ordering?: string;
    } = {
      ordering: "-id",
    };
    if (type) params.type = type;
    if (topic) params.topic = topic;
    if (debouncedSearchTerm) params.search = debouncedSearchTerm;
    return params;
  }, [type, topic, debouncedSearchTerm]);

  // Reset page to 1 when type, topic, or search actually changes (not on initialization)
  useEffect(() => {
    const currentFilters = { type, topic, search: debouncedSearchTerm };
    
    // Skip reset on first render (initialization)
    if (!isInitializedRef.current) {
      prevFiltersRef.current = currentFilters;
      isInitializedRef.current = true;
      return;
    }
    
    // Check if any filter actually changed
    const hasFilterChanged = 
      prevFiltersRef.current.type !== currentFilters.type ||
      prevFiltersRef.current.topic !== currentFilters.topic ||
      prevFiltersRef.current.search !== currentFilters.search;
    
    if (hasFilterChanged) {
      setPage("1");
      prevFiltersRef.current = currentFilters;
    }
  }, [type, topic, debouncedSearchTerm, setPage]);

  // Fetch pages info when filters change
  useEffect(() => {
    const fetchPagesInfo = async () => {
      try {
        const info = await getPagesInfo(searchParams);
        setPagesInfo(info);

        // Reset to page 1 if current page is out of bounds
        if (currentPage > info.total_pages) {
          setPage("1");
        }
      } catch (err) {
        console.error("Failed to fetch pages info:", err);
        setError("Failed to load pagination info");
      }
    };

    fetchPagesInfo();
  }, [searchParams, setPage, currentPage]);

  // Fetch quotes for current page
  useEffect(() => {
    const fetchQuotes = async () => {
      if (!pagesInfo) return;

      setLoading(true);
      setError(null);

      try {
        const data = await getQuotesPage(currentPage, searchParams);
        setQuotes(data.results);

        // Scroll to top when page changes
        window.scrollTo(0, 0);
      } catch (err) {
        console.error("Failed to fetch quotes:", err);
        setError("Failed to load quotes");
        setQuotes([]);
      } finally {
        setLoading(false);
      }
    };

    fetchQuotes();
  }, [currentPage, pagesInfo, searchParams]);

  const handleSelect = (value: string | number | null) => {
    setType(value?.toString() || null);
  };

  const handleSelectTopic = (value: string | number | null) => {
    setTopic(value?.toString() || null);
  };

  const handleSearch = (value: string) => {
    setSearch(value);
  };

  const handlePageChange = (newPage: number) => {
    setPage(newPage.toString());
  };

  if (error) {
    return (
      <div className="container relative">
        <Filter
          setSelect={handleSelect}
          setSelectTopic={handleSelectTopic}
          setSearch={handleSearch}
          selectedValue={type}
          selectedTopic={topic}
        />
        <div className="text-center py-8">
          <p className="text-red-500">Error: {error}</p>
        </div>
      </div>
    );
  }

  return (
    <div data-tid="layout" className="container relative">
      <Head>
        <title>Quotes List</title>
      </Head>

      <Filter
        setSelect={handleSelect}
        setSelectTopic={handleSelectTopic}
        setSearch={handleSearch}
        selectedValue={type}
        selectedTopic={topic}
      />

      <QuotesList
        quotes={quotes}
        loading={loading}
        error={error}
        showNumbers={true}
        topPagination={
          pagesInfo && !type && !topic && pagesInfo.total_pages > 1 ? (
            <div
              data-tid="pagination-desktop"
              className={cn(
                "sticky top-[120px] left-0 w-full pb-8 bg-background",
                "flex justify-start sm:hidden"
              )}
            >
              <Pagination
                currentPage={currentPage}
                pages={pagesInfo.pages}
                onPageChange={handlePageChange}
                disabled={loading}
                reversed={true}
              />
            </div>
          ) : undefined
        }
        bottomPagination={
          <div
            data-tid="pagination-mobile"
            className="container row sm:flex hidden pagination"
          >
            <a href="/">
              <div className="quote-button" />
            </a>

            {pagesInfo && !type && !topic && pagesInfo.total_pages > 1 && (
              <MobilePagination
                currentPage={currentPage}
                pages={pagesInfo.pages}
                onPageChange={handlePageChange}
                disabled={loading}
                reversed={true}
              />
            )}
          </div>
        }
      />
    </div>
  );
}
