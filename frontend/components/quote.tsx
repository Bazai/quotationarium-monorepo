import React from "react";
import { cn } from "../lib/utils";
import { QuoteProps, ListQuoteProps } from "../lib/types";

export const Quote: React.FC<QuoteProps> = ({ props, size, type }) => {
  return (
    <div data-tid="quote" className="flex flex-col gap-[16px] mb-[96px]">
      <p className="italic text-lg leading-5 font-normal ml-[0.1em] flex">
        {[props.author, props.book].join(", ")}
      </p>

      <p className={size?.toString()}>{props.quote}</p>
    </div>
  );
};

export const ListQuote: React.FC<ListQuoteProps> = ({ props, size }) => {
  return (
    <div
      className={cn(
        "mb-10 flex flex-col gap-2",
        "text-[26px] leading-[1.2]",
        "sm:mb-6 sm:-mt-[10px] sm:pt-[10px]",
        "sm:text-base sm:leading-[18px]"
      )}
    >
      <div
        className={cn(
          "hidden",
          "sm:flex sm:text-center sm:h-0 sm:border-t-2 sm:border-dotted",
          "sm:font-inter sm:mb-2 sm:text-[13px] sm:block sm:relative"
        )}
      >
        <span
          className={cn(
            "sm:absolute sm:-top-2 sm:left-1/2 sm:px-2 sm:bg-background sm:-translate-x-1/2"
          )}
        >
          {props.id}
        </span>
      </div>

      <p
        className={cn(
          "italic text-lg leading-5 font-normal ml-[0.1em] flex",
          "sm:gap-0 sm:order-2"
        )}
      >
        {[props.author, props.book].join(", ")}
      </p>

      <p>{props.quote}</p>
    </div>
  );
};

export default Quote;
