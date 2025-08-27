import { useState, useEffect, useCallback } from "react";
import { useDebounce } from "@uidotdev/usehooks";
import axios from "axios";
import { API_URL } from "../lib/constants";
import { Quote, PaginatedResponse } from "../lib/types";

interface UseQuotesSearchParams {
  searchTerm: string;
  type?: string | null;
  topic?: string | null;
  debounceMs?: number;
}

interface UseQuotesSearchReturn {
  quotes: Quote[];
  loading: boolean;
  error: string | null;
  hasSearched: boolean;
}

const sortByIdDesc = (a: Quote, b: Quote): number => {
  return b.id - a.id;
};

export const useQuotesSearch = ({
  searchTerm,
  type,
  topic,
  debounceMs = 300,
}: UseQuotesSearchParams): UseQuotesSearchReturn => {
  const [quotes, setQuotes] = useState<Quote[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasSearched, setHasSearched] = useState(false);

  const debouncedSearchTerm = useDebounce(searchTerm, debounceMs);

  const fetchQuotes = useCallback(async () => {
    if (!debouncedSearchTerm || debouncedSearchTerm.length === 0) {
      setQuotes([]);
      setHasSearched(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const searchParams = new URLSearchParams();
      searchParams.set("search", debouncedSearchTerm);
      searchParams.set("ordering", "-id");

      if (type) searchParams.set("type", type);
      if (topic) searchParams.set("topic", topic);

      const response = await axios.get<PaginatedResponse<Quote>>(
        `${API_URL}quotes?${searchParams.toString()}`
      );

      const quotesArray = response.data.results || [];

      const sortedQuotes = quotesArray.sort(sortByIdDesc);
      setQuotes(sortedQuotes);
      setHasSearched(true);
    } catch (err) {
      console.error("Failed to search quotes:", err);
      setError("Failed to search quotes");
      setQuotes([]);
    } finally {
      setLoading(false);
    }
  }, [debouncedSearchTerm, type, topic]);

  useEffect(() => {
    fetchQuotes();
  }, [fetchQuotes]);

  return {
    quotes,
    loading,
    error,
    hasSearched,
  };
};
