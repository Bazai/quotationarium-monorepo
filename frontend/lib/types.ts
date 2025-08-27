import axios from "axios";
import { API_URL } from "./constants";

export interface Type {
  id: number;
  name: string;
  type: string;
}

export interface Topic {
  id: number;
  topic: string;
}

export interface Quote {
  id: number;
  quote: string;
  author: string;
  book: string;
  type?: string;
  font_size?: string;
  signs?: number;
}

export interface EnrichedQuote extends Quote {
  count: number;
  step: number;
}

export interface SelectItem {
  id: number;
  type: string;
}

export interface GroupedQuotes {
  groupId: number;
  groupLabel: string;
  quotes: Quote[];
}

export interface PaginatedResponse<T> {
  count: number;
  total_pages: number;
  current_page: number;
  page_size: number;
  items_on_page: number;
  start_item: number;
  end_item: number;
  page_label: string;
  next: string | null;
  previous: string | null;
  results: T[];
}

export interface PageInfo {
  page: number;
  start_item: number;
  end_item: number;
  items_count: number;
  label: string;
}

export interface PagesInfoResponse {
  total_count: number;
  total_pages: number;
  page_size: number;
  pages: PageInfo[];
  pagination_disabled?: boolean;
}

export type Theme = "light" | "dark";

export interface FilterProps {
  setSelect: (value: string | number | null) => void;
  setSearch: (value: string) => void;
}

export interface QuoteProps {
  props: Quote | EnrichedQuote;
  size?: string | number;
  type?: string;
}

export interface ListQuoteProps {
  props: Quote | EnrichedQuote;
  size?: number;
}

export interface SliderProps {
  totalCount: number;
  currentPosition: number;
  onPositionChange: (position: number, force?: boolean) => void;
  disabled?: boolean;
}

export interface QuoteContainerProps {
  children: React.ReactNode;
  style?: React.CSSProperties;
  className?: string;
}

export interface QuotesListProps {
  quotes: Quote[];
  loading?: boolean;
  error?: string | null;
  showNumbers?: boolean;
  topPagination?: React.ReactNode;
  bottomPagination?: React.ReactNode;
}

export async function getTypes(): Promise<Type[]> {
  const response = await axios.get<Type[]>(API_URL + "types/");
  const json = response.data;
  return json;
}
