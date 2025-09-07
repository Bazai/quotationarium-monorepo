import axios from "axios";
import { API_URL } from "./constants";
import { Quote, Topic, PaginatedResponse, PagesInfoResponse } from "./types";

export async function getQuotes(): Promise<Quote[]> {
  const response = await axios.get<Quote[]>(API_URL + "quotes/");
  const json = response.data;
  return json;
}

export async function getQuotesPage(
  page: number,
  params?: { type?: string; topic?: string; search?: string; ordering?: string }
): Promise<PaginatedResponse<Quote>> {
  const searchParams = new URLSearchParams();
  searchParams.set("page", page.toString());

  if (params?.type) {
    searchParams.set("type", params.type);
  }
  if (params?.topic) {
    searchParams.set("topic", params.topic);
  }
  if (params?.search) {
    searchParams.set("search", params.search);
  }
  if (params?.ordering) {
    searchParams.set("ordering", params.ordering);
  }

  const response = await axios.get<PaginatedResponse<Quote>>(
    `${API_URL}quotes/?${searchParams.toString()}`
  );
  return response.data;
}

export async function getPagesInfo(params?: {
  type?: string;
  topic?: string;
  search?: string;
  ordering?: string;
}): Promise<PagesInfoResponse> {
  const searchParams = new URLSearchParams();

  if (params?.type) {
    searchParams.set("type", params.type);
  }
  if (params?.topic) {
    searchParams.set("topic", params.topic);
  }
  if (params?.search) {
    searchParams.set("search", params.search);
  }
  if (params?.ordering) {
    searchParams.set("ordering", params.ordering);
  }

  const url = `${API_URL}quotes/pages_info/?${searchParams.toString()}`;
  const response = await axios.get<PagesInfoResponse>(url);
  return response.data;
}

export async function getTopics(type?: string): Promise<Topic[]> {
  const searchParams = new URLSearchParams();

  if (type) {
    searchParams.set("type", type);
  }

  const url = `${API_URL}topics/?${searchParams.toString()}`;
  const response = await axios.get<Topic[]>(url);
  return response.data.sort((a, b) => a.id - b.id);
}
