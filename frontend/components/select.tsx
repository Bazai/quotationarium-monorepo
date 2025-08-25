import React, { useState, useRef, useEffect } from "react";
import { SelectItem } from "../lib/types";
import { Icon } from "./icon";
import { cn } from "../lib/utils";

interface SelectProps {
  items: SelectItem[];
  placeholder?: string;
  onSelect: (id: string | number) => void;
  selectedValue?: string | number | null;
}

const Select: React.FC<SelectProps> = ({
  items,
  onSelect,
  selectedValue,
  placeholder = "Выбрать приём",
}) => {
  const ref = useRef<HTMLDivElement>(null);
  const [title, setTitle] = useState<string>(placeholder);
  const [open, setOpen] = useState<boolean>(false);

  // Update title when selectedValue changes
  useEffect(() => {
    if (selectedValue) {
      const selectedItem = items.find(
        (item) => item.id.toString() === selectedValue.toString()
      );
      if (selectedItem) {
        setTitle(selectedItem.type);
      }
    } else {
      setTitle(placeholder);
    }
  }, [selectedValue, items]);

  useClickOutside(ref, () => {
    setOpen(false);
  });

  const handleOpen = () => {
    setOpen(!open);
  };

  const handleSelect = (id: number, type: string) => {
    onSelect(id);
    setTitle(type);
  };

  const isSelected = React.useMemo(() => title !== placeholder, [title]);

  const handleClose = (e: React.MouseEvent) => {
    setOpen(false);
  };

  const handleReset = (e: React.MouseEvent) => {
    e.stopPropagation();
    setOpen(false);
    setTitle(placeholder);
    onSelect("");
  };

  return (
    <div
      className={cn(
        "h-10 w-full relative flex items-center cursor-pointer rounded-2xl font-inter text-lg px-4 pr-12",
        isSelected
          ? "text-background bg-secondary-background hover:bg-secondary-background"
          : "bg-secondary text-primary hover:bg-dotted"
      )}
      onClick={handleOpen}
    >
      <span className="truncate">{title}</span>
      {!isSelected && (
        <Icon name="arrowDown" className="absolute top-2 right-4 w-6 h-6" />
      )}
      {isSelected && (
        <Icon
          name="close"
          reverse
          className="absolute top-2 right-4 z-[99] w-6 h-6"
          onClick={handleReset}
        />
      )}
      {open && (
        <div
          className={cn(
            "bg-secondary-background absolute top-12 left-0 w-full rounded-2xl",
            "text-secondary text-base font-inter max-h-[515px] overflow-y-scroll z-[98]"
          )}
          style={{
            scrollbarWidth: "auto",
            scrollbarColor: "var(--background) var(--primary)",
          }}
          ref={ref}
        >
          <ul className="list-none p-0 m-0">
            {items.map((item) => {
              return (
                <li
                  key={item.id}
                  className="py-2 px-4 border-b border-primary-dim cursor-pointer"
                  onClick={() => handleSelect(item.id, item.type)}
                >
                  {item.type}
                </li>
              );
            })}
          </ul>
        </div>
      )}
    </div>
  );
};

const useClickOutside = (
  ref: React.RefObject<HTMLDivElement>,
  handler: (event: Event) => void
) => {
  useEffect(() => {
    const listener = (event: Event) => {
      if (!ref.current || ref.current.contains(event.target as Node)) {
        return;
      }
      handler(event);
    };
    document.addEventListener("mousedown", listener);
    document.addEventListener("touchstart", listener);
    return () => {
      document.removeEventListener("mousedown", listener);
      document.removeEventListener("touchstart", listener);
    };
  }, [ref, handler]);
};

export default Select;
