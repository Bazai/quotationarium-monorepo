import React, { useState, useEffect } from "react";
import axios from "axios";
import { URL, API_URL } from "../lib/constants";
import { useRouter } from "next/router";
import ThemeToggle from "./theme-toggle";
import { cn } from "../lib/utils";
import LogoDesktop from "../components/logo";
import css from "./filter.module.css";
import Select from "./select";
import { Type, Topic } from "../lib/types";
import { getTopics } from "../lib/quotes";

interface CloseIconProps {
  className?: string;
  onClick?: (e: React.MouseEvent) => void;
}

const CloseIcon: React.FC<CloseIconProps> = ({ className, onClick }) => {
  return (
    <svg
      className={className}
      onClick={onClick}
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M20 4L12 12L4 4" stroke="#F1EFEC" strokeWidth="3" />
      <path d="M4 20L12 12L20 20" stroke="#F1EFEC" strokeWidth="3" />
    </svg>
  );
};

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
      <LogoDesktop />

      <div data-tid="header-mobile" className={css.mobile}>
        <div className="inline-flex h-fit">
          <a href="https://www.timuroki.ink/" target="_blank">
            <div className="logo-sm" />
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
        <div className={"sm:hidden " + css.viewToggle}>
          {router.pathname == "/list" ? (
            <a href="/">
              <div className="quote-button" />
            </a>
          ) : (
            <a href="/list">
              <div className="list" />
            </a>
          )}
        </div>

        <div className={isSearchActive ? css.searchActive : css.search}>
          {!isSearchEmpty && (
            <CloseIcon className={css.closeIcon} onClick={handleClearSearch} />
          )}

          <input
            type="text"
            value={searchTerm}
            placeholder="Найти что-нибудь"
            onChange={handleChange}
            onFocus={(e) => {
              setIsSearchActive(true);
            }}
            onBlur={(e) => {
              if (searchTerm === "") {
                setIsSearchActive(false);
              }
            }}
          ></input>
          <svg
            className={css.searchIcon}
            width="24"
            height="24"
            viewBox="0 0 25 25"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <circle
              cx="9"
              cy="9"
              r="7.5"
              transform="matrix(-1 0 0 1 18 0)"
              stroke="#232740"
              strokeWidth="3"
            />
            <path d="M15 15L23.25 23.25" stroke="#232740" strokeWidth="3" />
          </svg>
        </div>

        {/* Type Select */}
        <div className={isSearchActive ? css.selectInactive : css.select}>
          <Select
            placeholder="Выбрать приём"
            items={types}
            onSelect={setSelect}
            selectedValue={selectedValue}
          />
        </div>

        {/* Topic Select */}
        <div
          className={cn(
            css.select,
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

        <div className={"sm:hidden ml-auto " + css.themeToggle}>
          <ThemeToggle />
        </div>
      </div>
    </div>
  );
};
export default Filter;
