import { useState, useEffect, useMemo } from "react";
import { Quote } from "../lib/types";

interface ClientSidePaginationConfig {
  type: "client";
  data: Quote[];
  itemsPerPage?: number;
}

interface ServerSidePaginationConfig {
  type: "server";
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
}

type PaginationConfig = ClientSidePaginationConfig | ServerSidePaginationConfig;

interface PaginationReturn {
  currentPage: number;
  totalPages: number;
  currentData: Quote[];
  pageLabels: string[];
  canGoNext: boolean;
  canGoPrevious: boolean;
  goToPage: (page: number) => void;
  goNext: () => void;
  goPrevious: () => void;
}

export const useQuotesPagination = (
  config: PaginationConfig
): PaginationReturn => {
  const [currentPage, setCurrentPage] = useState(1);

  // Client-side pagination logic
  const clientPagination = useMemo(() => {
    if (config.type !== "client") return null;

    const { data, itemsPerPage = 100 } = config;
    const totalPages = Math.ceil(data.length / itemsPerPage);
    
    // Create page groups
    const pages: Quote[][] = [];
    const pageLabels: string[] = [];
    
    for (let i = 0; i < totalPages; i++) {
      const start = i * itemsPerPage;
      const end = Math.min(start + itemsPerPage, data.length);
      const pageData = data.slice(start, end);
      
      if (pageData.length > 0) {
        pages.push(pageData);
        
        // Create label based on ID range
        const minId = Math.min(...pageData.map(q => q.id));
        const maxId = Math.max(...pageData.map(q => q.id));
        pageLabels.push(`${minId} - ${maxId}`);
      }
    }

    return {
      pages,
      pageLabels,
      totalPages: pages.length,
    };
  }, [config]);

  // Reset page when data changes (client-side)
  useEffect(() => {
    if (config.type === "client") {
      setCurrentPage(Math.min(currentPage, clientPagination?.totalPages || 1));
    }
  }, [config, currentPage, clientPagination?.totalPages]);

  // Server-side pagination
  const serverPagination = useMemo(() => {
    if (config.type !== "server") return null;
    return {
      currentPage: config.currentPage,
      totalPages: config.totalPages,
      onPageChange: config.onPageChange,
    };
  }, [config]);

  const goToPage = (page: number) => {
    if (config.type === "client") {
      const maxPage = clientPagination?.totalPages || 1;
      const newPage = Math.max(1, Math.min(page, maxPage));
      setCurrentPage(newPage);
    } else {
      serverPagination?.onPageChange(page);
    }
  };

  const goNext = () => {
    const total = config.type === "client" 
      ? clientPagination?.totalPages || 1
      : serverPagination?.totalPages || 1;
    const current = config.type === "client" 
      ? currentPage 
      : serverPagination?.currentPage || 1;
    
    if (current < total) {
      goToPage(current + 1);
    }
  };

  const goPrevious = () => {
    const current = config.type === "client" 
      ? currentPage 
      : serverPagination?.currentPage || 1;
    
    if (current > 1) {
      goToPage(current - 1);
    }
  };

  // Calculate return values
  const finalCurrentPage = config.type === "client" 
    ? currentPage 
    : serverPagination?.currentPage || 1;
  
  const finalTotalPages = config.type === "client" 
    ? clientPagination?.totalPages || 1
    : serverPagination?.totalPages || 1;

  const currentData = config.type === "client" 
    ? clientPagination?.pages[currentPage - 1] || []
    : [];

  const pageLabels = config.type === "client" 
    ? clientPagination?.pageLabels || []
    : [];

  return {
    currentPage: finalCurrentPage,
    totalPages: finalTotalPages,
    currentData,
    pageLabels,
    canGoNext: finalCurrentPage < finalTotalPages,
    canGoPrevious: finalCurrentPage > 1,
    goToPage,
    goNext,
    goPrevious,
  };
};