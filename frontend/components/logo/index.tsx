const LogoSvg = require("./assets/logo.svg").default;

type LogoProps = {
  size?: number;
} & React.HTMLAttributes<HTMLDivElement>;

export function Logo({ size = 200, ...rest }: LogoProps) {
  return (
    <div
      style={{
        width: size,
        height: "auto",
      }}
      {...rest}
    >
      <LogoSvg />
    </div>
  );
}

export default Logo;
