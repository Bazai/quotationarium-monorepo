import React, { useState, useEffect } from "react";
import axios from "axios";
import { API_URL } from "../lib/constants";
import { useRouter } from "next/router";
import ThemeToggle from "./theme-toggle";
import { cn } from "../lib/utils";
import Select from "./select";
import { Type, Topic } from "../lib/types";
import { getTopics } from "../lib/quotes";
import { Icon } from "./icon";
import { Logo } from "./logo";

interface FilterProps {
  setSelect: (value: string | number | null) => void;
  setSelectTopic: (value: string | number | null) => void;
  setSearch: (value: string) => void;
  selectedValue?: string | number | null;
  selectedTopic?: string | number | null;
}

const Filter: React.FC<FilterProps> = ({
  setSelect,
  setSelectTopic,
  setSearch,
  selectedValue,
  selectedTopic,
}) => {
  const router = useRouter();
  const [types, setTypes] = useState<Type[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [isSearchActive, setIsSearchActive] = useState(false);
  const [isSearchEmpty, setIsSearchEmpty] = useState(true);

  // Fetch types with topic filter
  useEffect(() => {
    const fetchTypes = async () => {
      const searchParams = new URLSearchParams();
      if (selectedTopic) {
        searchParams.set("topic", selectedTopic.toString());
      }

      const url = `${API_URL}types/?${searchParams.toString()}`;
      const data = await axios.get<Type[]>(url);
      setTypes(data.data);
    };
    fetchTypes();
  }, [selectedTopic]);

  // Fetch topics with type filter
  useEffect(() => {
    const fetchTopics = async () => {
      const topicsData = await getTopics(selectedValue?.toString());
      setTopics(topicsData);
    };
    fetchTopics();
  }, [selectedValue]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setSearchTerm(value);
    if (value !== "") {
      setIsSearchEmpty(false);
    } else {
      setIsSearchEmpty(true);
    }
    setSearch(value);
  };

  const handleClearSearch = (e: React.MouseEvent) => {
    setSearchTerm("");
    setIsSearchEmpty(true);
    setIsSearchActive(false);
    setSearch("");
  };

  return (
    <div
      data-tid="top"
      className={cn(
        "container flex-col fixed z-10 top-0 left-0 right-0",
        "h-[120px] sm:h-[160px] bg-background",
        "min-w-[360px]"
      )}
    >
      <a
        href="https://www.timuroki.ink/"
        target="_blank"
        className={cn(
          "sm:hidden cursor-pointer",
          "absolute top-[320px] left-9",
          "text-secondary hover:text-secondary-background",
          "transition-colors duration-300",
          "-rotate-90 origin-left"
        )}
      >
        <Logo />
      </a>

      <div
        data-tid="header-mobile"
        className={cn("hidden", "sm:flex sm:items-center sm:h-14")}
      >
        <div className="inline-flex h-fit">
          <a href="https://www.timuroki.ink/" target="_blank">
            <Logo />
          </a>
        </div>

        <div className="ml-auto">
          <ThemeToggle />
        </div>
      </div>

      <div
        data-tid="header-inner"
        className={cn(
          "grid grid-cols-[48px_1fr_1fr_1fr_116px] gap-4 w-full mt-10",
          "sm:m-0 sm:mb-4 sm:grid-cols-[56px_1fr] sm:gap-2"
        )}
      >
        <div className={"sm:hidden w-12 flex-0"}>
          {router.pathname == "/list" ? (
            <a href="/">
              <Icon
                className="rounded-2xl bg-secondary"
                name="quote"
                size={40}
              />
            </a>
          ) : (
            <a href="/list">
              <Icon
                className="rounded-2xl bg-secondary"
                name="list"
                size={40}
              />
            </a>
          )}
        </div>

        <div
          data-tid="search-input"
          className={cn(
            "flex-grow w-full relative",
            isSearchActive && "col-span-3 sm:col-span-2"
          )}
        >
          {!isSearchEmpty && (
            <Icon
              name="close"
              className="absolute top-2 right-4 z-10 w-6 h-6 cursor-pointer"
              onClick={handleClearSearch}
              reverse
            />
          )}

          <input
            type="text"
            value={searchTerm}
            placeholder="Найти что-нибудь"
            className={cn(
              "h-10 w-full rounded-2xl border-0 pl-12 pr-4",
              "text-lg text-primary font-inter",
              "bg-secondary hover:bg-dotted",
              "focus:bg-secondary-background focus:text-background focus:outline-none",
              "placeholder-shown:bg-secondary placeholder-shown:text-primary",
              "sm:pl-10 sm:focus:pl-12",
              isSearchActive && "pr-12"
            )}
            onChange={handleChange}
            onFocus={(e) => {
              setIsSearchActive(true);
            }}
            onBlur={(e) => {
              if (searchTerm === "") {
                setIsSearchActive(false);
              }
            }}
          />

          <Icon
            name="search"
            className="absolute z-10 pointer-events-none top-2 left-4"
            onClick={handleClearSearch}
            reverse={isSearchActive}
          />
        </div>

        {/* Type Select */}
        <div
          data-tid="type-select"
          className={cn("flex-grow w-full", isSearchActive && "hidden")}
        >
          <Select
            placeholder="Выбрать приём"
            items={types}
            onSelect={setSelect}
            selectedValue={selectedValue}
          />
        </div>

        {/* Topic Select */}
        <div
          data-tid="topic-select"
          className={cn(
            "flex-grow w-full",
            "sm:col-span-2",
            isSearchActive && "hidden"
          )}
        >
          <Select
            placeholder="Выбрать тему"
            items={topics.map((topic) => ({ id: topic.id, type: topic.topic }))}
            onSelect={setSelectTopic}
            selectedValue={selectedTopic}
          />
        </div>

        <div
          className={cn(
            "sm:hidden ml-auto",
            "w-[116px] flex-shrink-0 flex justify-end"
          )}
        >
          <ThemeToggle />
        </div>
      </div>
    </div>
  );
};
export default Filter;
