import React, { useState, useRef, useEffect } from "react";
import css from "./select.module.css";
import { SelectItem } from "../lib/types";

interface CloseIconProps {
  className?: string;
  onClick: (e: React.MouseEvent) => void;
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

interface DownIconProps {
  className?: string;
}

const DownIcon: React.FC<DownIconProps> = ({ className }) => {
  return (
    <svg
      className={className}
      width="24"
      height="24"
      viewBox="0 0 26 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M24 6L13 17L2 6" stroke="#232740" strokeWidth="3" />
    </svg>
  );
};

const placeholder = "Выбрать приём";

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
      className={isSelected ? css.selected : css.select}
      onClick={handleOpen}
    >
      <span className="truncate">{title}</span>
      {!isSelected && <DownIcon className={css.icon} />}
      {isSelected && <CloseIcon className={css.close} onClick={handleReset} />}
      {open && (
        <div className={css.dropdown} ref={ref}>
          <ul>
            {items.map((item) => {
              return (
                <li
                  key={item.id}
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
