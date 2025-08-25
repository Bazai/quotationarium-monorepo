const iconsMap = {
  arrowDown: require("./assets/arrow_down.svg").default,
  arrowLeft: require("./assets/arrow_left.svg").default,
  arrowRight: require("./assets/arrow_right.svg").default,
  close: require("./assets/close.svg").default,
  list: require("./assets/list.svg").default,
  quote: require("./assets/quote.svg").default,
  search: require("./assets/search.svg").default,
  moon: require("./assets/moon.svg").default,
  sun: require("./assets/sun.svg").default,
} as const;

type IconProps = {
  name: keyof typeof iconsMap;
  variant?: "primary" | "secondary";
  size?: number;
  reverse?: boolean;
} & React.HTMLAttributes<HTMLDivElement>;

export function Icon({
  name,
  variant,
  size = 24,
  reverse,
  ...rest
}: IconProps) {
  const Component = iconsMap[name];
  return (
    <div
      style={{
        color: variant
          ? `var(--icon-color-${variant})`
          : reverse
          ? `var(--icon-color-reverse)`
          : `var(--icon-color)`,
        // color:  `var(--icon-color)`,
        width: size,
        height: size,
      }}
      {...rest}
    >
      <Component className="w-full h-full" />
    </div>
  );
}
