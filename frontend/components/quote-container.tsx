import React from "react";
import { cn } from "../lib/utils";
import { QuoteContainerProps } from "../lib/types";

const QuoteContainer: React.FC<QuoteContainerProps> = ({ children, style }) => {
  return (
    <div
      data-tid="quote-container"
      className={cn(
        "w-full pt-[120px] pl-[64px] min-h-[calc(100vh-80px)]",
        "sm:pl-0 pr-[80px] sm:pr-0 sm:pt-[164px]"
      )}
      style={style}
    >
      {children}
    </div>
  );
};

export const ListQuoteContainer: React.FC<QuoteContainerProps> = ({
  children,
  className,
}) => {
  return (
    <div
      data-tid="list-quote-container"
      className={cn(
        "w-full pt-[120px] px-[64px] min-h-screen",
        "sm:pr-0 sm:pl-0 sm:pt-[164px] sm:mb-[72px]",
        className
      )}
    >
      {children}
    </div>
  );
};

export default QuoteContainer;
