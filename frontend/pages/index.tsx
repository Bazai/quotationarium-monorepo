import React, { useState, useEffect, useRef, useCallback } from "react";
import { useDebounce } from "@uidotdev/usehooks";
import { useThrottle } from "../hooks/useThrottle";
import { useQueryState } from "nuqs";
import Filter from "../components/filter";
import Quote from "../components/quote";
import axios from "axios";
import { API_URL } from "../lib/constants";
import Slider from "../components/slider";
import QuoteContainer from "../components/quote-container";
import SearchQuotes from "../components/search-quotes";
import { Icon } from "../components/icon";
import { Quote as QuoteType, EnrichedQuote } from "../lib/types";
import { cn } from "@/lib/utils";

export default function Home() {
  console.log("2808 deploy testing");
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

  const throttledPosition = useThrottle(currentPosition, 300); // For drag preview (shows every 30ms)
  const debouncedPosition = useDebounce(currentPosition, 150); // For final position (after drag stops)

  // Cache for recently fetched quotes
  const quoteCache = useRef<Map<number, EnrichedQuote>>(new Map());

  // AbortController for cancelling in-flight requests
  const abortControllerRef = useRef<AbortController | null>(null);

  // Track if we're currently dragging to prevent unnecessary fetches
  const isDragging = useRef<boolean>(false);

  // Track last processed positions to prevent duplicate requests
  const lastThrottlePosition = useRef<number>(0);

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

  // Effect for THROTTLE - handles drag preview quotes (300ms intervals)
  useEffect(() => {
    if (throttledPosition === 0 || !isDragging.current) {
      return;
    }

    // Prevent duplicate requests for the same position
    if (lastThrottlePosition.current === throttledPosition) {
      return;
    }

    lastThrottlePosition.current = throttledPosition;

    // Check cache first
    const cachedQuote = quoteCache.current.get(throttledPosition);
    if (cachedQuote) {
      setQuote(cachedQuote);
      return;
    }

    // Fetch quote for drag preview
    fetchQuoteAtPosition(throttledPosition)
      .then((newQuote) => {
        if (newQuote) {
          // Cache the quote
          if (quoteCache.current.size >= 20) {
            const firstKey = quoteCache.current.keys().next().value;
            if (firstKey !== undefined) {
              quoteCache.current.delete(firstKey);
            }
          }
          quoteCache.current.set(throttledPosition, newQuote);
          setQuote(newQuote);
        }
      })
      .catch((error) => {
        console.error("❌ THROTTLE: Failed to fetch drag preview:", error);
      });
  }, [throttledPosition, fetchQuoteAtPosition]);

  // Effect for DEBOUNCE - handles final position after drag stops (150ms)
  useEffect(() => {
    if (debouncedPosition === 0 || isDragging.current) {
      return;
    }

    // Check cache first
    const cachedQuote = quoteCache.current.get(debouncedPosition);
    if (cachedQuote) {
      setQuote(cachedQuote);
      return;
    }

    // Fetch quote for final position
    fetchQuoteAtPosition(debouncedPosition)
      .then((newQuote) => {
        if (newQuote) {
          // Cache the quote
          if (quoteCache.current.size >= 20) {
            const firstKey = quoteCache.current.keys().next().value;
            if (firstKey !== undefined) {
              quoteCache.current.delete(firstKey);
            }
          }
          quoteCache.current.set(debouncedPosition, newQuote);
          setQuote(newQuote);
        }
      })
      .catch((error) => {
        console.error("❌ DEBOUNCE: Failed to fetch final quote:", error);
      });
  }, [debouncedPosition, fetchQuoteAtPosition, currentPosition]);

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
    // Clear cache when filters change
    quoteCache.current.clear();

    // Reset dragging state
    isDragging.current = false;

    if (typeof window !== "undefined") {
      initializeData();
    }
  }, [type, topic]); // eslint-disable-line react-hooks/exhaustive-deps

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
    (newPosition: number, force: boolean = false) => {
      if (newPosition === currentPosition && !force) {
        return;
      }

      // Update dragging state
      if (force) {
        isDragging.current = false;
        // Reset throttle position tracker when dragging ends
        lastThrottlePosition.current = 0;
      } else {
        isDragging.current = true;
      }

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

      // Handle force fetch on mouseUp
      if (force) {
        // Force fetch on mouseUp for immediate response
        fetchQuoteAtPosition(newPosition).then((newQuote) => {
          if (newQuote) {
            // Cache the quote
            if (quoteCache.current.size >= 20) {
              const firstKey = quoteCache.current.keys().next().value;
              if (firstKey !== undefined) {
                quoteCache.current.delete(firstKey);
              }
            }
            quoteCache.current.set(newPosition, newQuote);
            setQuote(newQuote);
          }
        });
      }
    },
    [currentPosition, totalCount, fetchQuoteAtPosition]
  );

  return (
    <>
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
              data-tid="pagination-mobile-wrapper"
              className={cn(
                "hidden sm:flex gap-2 container w-full",
                "bg-transparent pb-0",
                "fixed top-auto left-0 bottom-4"
              )}
            >
              <a
                href="/list"
                className="w-[56px] h-10 cursor-pointer rounded-2xl bg-secondary inline-flex justify-center items-center"
              >
                <Icon name="list" size={40} />
              </a>

              <div className="ml-auto flex gap-2">
                <button
                  className="w-[56px] h-10 cursor-pointer rounded-2xl bg-secondary inline-flex justify-center items-center"
                  onClick={decreaseProgress}
                >
                  <Icon name="arrowLeft" size={24} />
                </button>
                <button
                  className="w-[56px] h-10 cursor-pointer rounded-2xl bg-secondary inline-flex justify-center items-center"
                  onClick={increaseProgress}
                >
                  <Icon name="arrowRight" size={24} />
                </button>
              </div>
            </div>
          </>
        )}
      </div>
    </>
  );
}
