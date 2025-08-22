import React from "react";
import css from "./quote.module.css";
import { cn } from "../lib/utils";
import { QuoteProps, ListQuoteProps } from "../lib/types";

export const Quote: React.FC<QuoteProps> = ({ props, size, type }) => {
  return (
    <div data-tid="quote" className="flex flex-col gap-[16px] mb-[96px]">
      <p className={css.title}>
        {[props.author, props.book].join(", ")}
      </p>

      <p className={size?.toString()}>{props.quote}</p>
    </div>
  );
};

export const ListQuote: React.FC<ListQuoteProps> = ({ props, size }) => {
  return (
    <div className={css.listContainer}>
      <div className={css.dotted}>
        <span>{props.id}</span>
      </div>

      <p className={css.title}>
        {[props.author, props.book].join(", ")}
      </p>

      <p>{props.quote}</p>
    </div>
  );
};

export default Quote;