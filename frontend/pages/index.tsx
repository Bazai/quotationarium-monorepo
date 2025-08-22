import React, { useState, useEffect, useRef, useCallback } from "react";
import { useDebounce } from "@uidotdev/usehooks";
import { useQueryState } from "nuqs";
import Head from "next/head";
import Filter from "../components/filter";
import Quote from "../components/quote";
import axios from "axios";
import { API_URL } from "../lib/constants";
import Slider from "../components/slider";
import LogoDesktop from "../components/logo";
import QuoteContainer from "../components/quote-container";
import SearchQuotes from "../components/search-quotes";
import { Quote as QuoteType, EnrichedQuote } from "../lib/types";

export default function Home() {
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
  const [search, setSearch] = useState<string>("");
  const [quote, setQuote] = useState<EnrichedQuote | null>(null);
  const [totalCount, setTotalCount] = useState<number>(0);
  const [currentPosition, setCurrentPosition] = useState<number>(0);
  const [progress, setProgress] = useState<number>(0);
  const [loading, setLoading] = useState<boolean>(true);

  const debouncedSearchTerm = useDebounce(search, 300);

  // Cache for recently fetched quotes
  const quoteCache = useRef<Map<number, EnrichedQuote>>(new Map());

  // AbortController for cancelling in-flight requests
  const abortControllerRef = useRef<AbortController | null>(null);

  const fetchTotalCount = async (signal?: AbortSignal): Promise<number> => {
    if (typeof window === "undefined") return 0;

    try {
      const searchParams = new URLSearchParams();
      if (type) searchParams.set("type", type);
      if (topic) searchParams.set("topic", topic);
      const tail = searchParams.toString() ? `?${searchParams.toString()}` : "";

      const { data } = await axios.get<{ total_count: number }>(
        `${API_URL}quotes/total_count/${tail}`,
        { signal }
      );
      return data.total_count;
    } catch (error) {
      if (axios.isCancel(error)) {
        console.log("Request cancelled");
      } else {
        console.error("Failed to fetch total count:", error);
      }
      return 0;
    }
  };

  const fetchQuoteAtPosition = useCallback(
    async (
      position: number,
      signal?: AbortSignal
    ): Promise<EnrichedQuote | null> => {
      if (typeof window === "undefined") return null;

      try {
        const searchParams = new URLSearchParams();
        if (type) searchParams.set("type", type);
        if (topic) searchParams.set("topic", topic);
        searchParams.set("position", position.toString());

        const { data } = await axios.get<QuoteType>(
          `${API_URL}quotes/?${searchParams.toString()}`,
          { signal }
        );

        return {
          ...data,
          count: position - 1, // Keep for compatibility
          step: 0, // Will be calculated based on totalCount
        };
      } catch (error) {
        if (!axios.isCancel(error)) {
          console.error("Failed to fetch quote at position:", error);
        }
        return null;
      }
    },
    [type, topic]
  );

  // Debounced fetch for position changes
  const debouncedFetchRef = useRef<NodeJS.Timeout>();
  const lastRequestedPositionRef = useRef<number>(0);

  const debouncedFetchQuoteAtPosition = useCallback(
    (position: number) => {
      // Clear previous timeout
      if (debouncedFetchRef.current) {
        clearTimeout(debouncedFetchRef.current);
      }

      // Update last requested position
      lastRequestedPositionRef.current = position;

      // Set new timeout for fetch
      debouncedFetchRef.current = setTimeout(async () => {
        // Only fetch if this is still the latest requested position
        if (lastRequestedPositionRef.current === position) {
          const newQuote = await fetchQuoteAtPosition(position);
          if (newQuote && lastRequestedPositionRef.current === position) {
            // Cache the quote
            if (quoteCache.current.size >= 20) {
              const firstKey = quoteCache.current.keys().next().value;
              if (firstKey !== undefined) {
                quoteCache.current.delete(firstKey);
              }
            }
            quoteCache.current.set(position, newQuote);

            // Update quote without checking currentPosition
            setQuote(newQuote);
          }
        }
      }, 30);
    },
    [fetchQuoteAtPosition]
  );

  const initializeData = async () => {
    // Cancel any in-flight requests
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }

    // Create new abort controller for this request
    const abortController = new AbortController();
    abortControllerRef.current = abortController;

    try {
      setLoading(true);
      // Reset totalCount immediately to prevent using stale value
      setTotalCount(0);
      setCurrentPosition(0);

      const total = await fetchTotalCount(abortController.signal);

      // Check if request was cancelled
      if (abortController.signal.aborted) return;

      if (total === 0) {
        setQuote(null);
        setLoading(false);
        return;
      }

      // Select random position (1-based)
      const randomPosition = Math.floor(Math.random() * total) + 1;
      const selectedQuote = await fetchQuoteAtPosition(
        randomPosition,
        abortController.signal
      );

      // Check if request was cancelled
      if (abortController.signal.aborted) return;

      if (selectedQuote) {
        const progress =
          total === 1 ? 50 : ((randomPosition - 1) / (total - 1)) * 100;

        setTotalCount(total);
        setCurrentPosition(randomPosition);
        setQuote(selectedQuote);
        setProgress(progress);
      }
    } catch (error) {
      if (!axios.isCancel(error)) {
        console.error("Failed to initialize data:", error);
      }
    } finally {
      if (!abortController.signal.aborted) {
        setLoading(false);
      }
    }
  };

  useEffect(() => {
    // Clear cache and debounced requests when filters change
    quoteCache.current.clear();

    if (debouncedFetchRef.current) {
      clearTimeout(debouncedFetchRef.current);
      debouncedFetchRef.current = undefined;
    }

    // Reset last requested position
    lastRequestedPositionRef.current = 0;

    if (typeof window !== "undefined") {
      initializeData();
    }
  }, [type, topic]); // eslint-disable-line react-hooks/exhaustive-deps

  // Cleanup debounced timeout on unmount
  useEffect(() => {
    return () => {
      if (debouncedFetchRef.current) {
        clearTimeout(debouncedFetchRef.current);
      }
    };
  }, []);

  const handleSelect = (value: string | number | null) => {
    setType(value?.toString() || null);
  };

  const handleSelectTopic = (value: string | number | null) => {
    setTopic(value?.toString() || null);
  };

  const handleSearch = (value: string) => {
    setSearch(value);
  };

  // Legacy navigation functions for mobile pagination (kept for compatibility)
  const decreaseProgress = () =>
    handlePositionChange(Math.max(1, currentPosition - 1));
  const increaseProgress = () =>
    handlePositionChange(Math.min(totalCount, currentPosition + 1));

  // Handle position change from Slider
  const handlePositionChange = useCallback(
    (newPosition: number) => {
      if (newPosition === currentPosition) return;

      // Update position and progress immediately for smooth UI
      setCurrentPosition(newPosition);
      const newProgress =
        totalCount > 1 ? ((newPosition - 1) / (totalCount - 1)) * 100 : 50;
      setProgress(newProgress);

      // Check cache first
      const cachedQuote = quoteCache.current.get(newPosition);
      if (cachedQuote) {
        setQuote(cachedQuote);
        return;
      }

      // Use debounced fetch for non-cached quotes
      debouncedFetchQuoteAtPosition(newPosition);
    },
    [currentPosition, totalCount, debouncedFetchQuoteAtPosition]
  );

  return (
    <>
      <Head>
        <title>Словомеханики</title>
      </Head>
      <div data-tid="layout" className="container relative">
        <Filter
          setSelect={handleSelect}
          setSelectTopic={handleSelectTopic}
          setSearch={handleSearch}
          selectedValue={type}
          selectedTopic={topic}
        />

        {/* {search.length > 0 ? ( */}
        {debouncedSearchTerm.length > 0 ? (
          <SearchQuotes
            search={debouncedSearchTerm}
            type={type}
            topic={topic}
          />
        ) : (
          <>
            <QuoteContainer>
              {loading === false && quote && (
                <Quote props={quote} size={quote.font_size} type={"index"} />
              )}
            </QuoteContainer>

            <Slider
              totalCount={totalCount}
              currentPosition={currentPosition}
              onPositionChange={handlePositionChange}
            />

            <div
              data-tid="pagination-mobile"
              className="container pagination hidden sm:flex"
            >
              <a href="/list">
                <div className="list" />
              </a>

              <div className="ml-auto flex gap-2">
                <div onClick={decreaseProgress} className="arrow-left" />
                <div onClick={increaseProgress} className="arrow-right" />
              </div>
            </div>
          </>
        )}
      </div>
    </>
  );
}
