import React from "react";
import { ListQuote } from "./quote";
import { ListQuoteContainer } from "./quote-container";
import { QuotesListProps } from "../lib/types";

const QuotesList: React.FC<QuotesListProps> = ({
  quotes,
  loading = false,
  error = null,
  showNumbers = true,
  topPagination,
  bottomPagination,
}) => {
  if (loading) {
    return (
      <ListQuoteContainer>
        {topPagination}
        <div className="text-center py-8">
          <p className="hidden">Загрузка...</p>
        </div>
      </ListQuoteContainer>
    );
  }

  if (error) {
    return (
      <ListQuoteContainer>
        <div className="text-center py-8">
          <p className="text-red-500">Ошибка: {error}</p>
        </div>
      </ListQuoteContainer>
    );
  }

  if (!quotes || quotes.length === 0) {
    return (
      <ListQuoteContainer>
        <div className="text-center py-8">
          <p>Ничего не найдено</p>
        </div>
      </ListQuoteContainer>
    );
  }

  return (
    <>
      <ListQuoteContainer>
        {topPagination}
        {quotes.map((quote) => (
          <div className="flex" key={quote.id}>
            {showNumbers && (
              <div className="sm:hidden w-[93px] shrink-0">
                <p className="inter quote-number">{quote.id}.</p>
              </div>
            )}
            <div className="col sm:w-full">
              <ListQuote props={quote} size={26} />
            </div>
          </div>
        ))}
      </ListQuoteContainer>
      {bottomPagination}
    </>
  );
};

QuotesList.displayName = "QuotesList";

export default QuotesList;
