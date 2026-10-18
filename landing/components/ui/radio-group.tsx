"use client";
import { Radio as RadioPrimitive } from "@base-ui/react/radio";
import { RadioGroup as RadioGroupPrimitive } from "@base-ui/react/radio-group";
import { cn } from "cn";
function RadioGroup({ className, ...props }: RadioGroupPrimitive.Props) {
  return (
    <RadioGroupPrimitive
      data-slot="radio-group"
      className={cn("ui-radio-group", className)}
      {...props}
    />
  );
}
function RadioGroupItem({
  className,
  children,
  ...props
}: RadioPrimitive.Root.Props) {
  return (
    <RadioPrimitive.Root
      data-slot="radio-group-item"
      className={cn("ui-radio", className)}
      {...props}
    >
      {children ?? (
        <RadioPrimitive.Indicator
          data-slot="radio-group-indicator"
          className="ui-radio-indicator"
        />
      )}
    </RadioPrimitive.Root>
  );
}
export { RadioGroup, RadioGroupItem };
